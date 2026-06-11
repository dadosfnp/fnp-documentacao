"""
FNP Knowledge Base — Worker de Ingestão
Lê arquivos do DO Spaces (e futuramente Google Drive),
extrai texto, gera embeddings e salva no PostgreSQL.

Regra de ouro (ver ARQUITETURA.md, RDA-006):
    - DOCUMENTO (PDF, DOCX, PPTX, MD, TXT) você quer *encontrar* → vira embedding em rag.documentos.
    - DADO TABULAR (Parquet, Excel, CSV) você quer *consultar/cruzar* → NÃO é embedado aqui;
      vai para um schema do Núcleo (economia/social/...) via playbook-ingestao-dados.md e é
      respondido por text-to-SQL. O que o RAG indexa do Núcleo é o `.dicionario.md` (o mapa),
      nunca o Parquet em si. Por isso formatos tabulares ficam fora de EXTENSOES_VALIDAS.

Uso:
    python ingestor.py                  # indexa tudo que mudou
    python ingestor.py --force          # reindexar tudo
    python ingestor.py --arquivo KEY    # indexar arquivo específico
"""

import os
import hashlib
import argparse
import logging
from io import BytesIO
from datetime import datetime

import boto3
import psycopg2
from openai import OpenAI
from pypdf import PdfReader
from docx import Document
from pptx import Presentation
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)
log = logging.getLogger("fnp-ingestor")

# ── Clientes ──────────────────────────────────────────────────

openai_client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

s3 = boto3.client(
    "s3",
    region_name=os.getenv("DO_SPACES_REGION", "nyc3"),
    endpoint_url=os.getenv("DO_SPACES_ENDPOINT"),
    aws_access_key_id=os.getenv("DO_SPACES_KEY"),
    aws_secret_access_key=os.getenv("DO_SPACES_SECRET"),
)

BUCKET = os.getenv("DO_SPACES_BUCKET", "fnp-knowledge-base")

# Só documentos viram embedding. Dado tabular (xlsx/xls/parquet/csv) é tratado pelo
# fluxo do Núcleo de Dados (text-to-SQL), não por busca semântica — ver docstring do módulo.
EXTENSOES_VALIDAS = {"pdf", "docx", "doc", "pptx", "ppt", "md", "txt"}
EXTENSOES_TABULARES = {"xlsx", "xls", "parquet", "csv"}


def get_conn():
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=int(os.getenv("DB_PORT", 25060)),
        dbname=os.getenv("DB_NAME", "defaultdb"),
        user="ingestor",
        password=os.getenv("DB_PASS_INGESTOR"),
        sslmode=os.getenv("DB_SSL", "require"),
    )


# ── Utilitários ───────────────────────────────────────────────

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def extensao(key: str) -> str:
    return key.rsplit(".", 1)[-1].lower() if "." in key else ""


def detectar_sistema(key: str) -> str | None:
    """Extrai nome do sistema se arquivo estiver em sistemas/"""
    if "sistemas/" in key:
        partes = key.split("sistemas/")
        if len(partes) > 1:
            return partes[1].split("/")[0]
    return None


# Mapa pasta → nível de acesso (LGPD, ver RDA-007). O nível é derivado do prefixo
# do Key no Spaces, que espelha a estrutura de pastas do Drive. O assistente filtra
# os chunks por este nível conforme o usuário, para não vazar trecho restrito.
# Casa pelo trecho mais específico encontrado no caminho; default conservador = 'interno'.
PREFIXOS_NIVEL_ACESSO = {
    "documentos/administrativo/": "restrito",
    "documentos/contratos/":      "restrito",
    "documentos/regulamentos/":   "publico",
    "documentos/apresentacoes/":  "interno",
}


def classificar_nivel_acesso(key: str) -> str:
    """Deriva o nível de acesso (publico|interno|restrito) pela pasta de origem.

    Default conservador 'interno': na dúvida, não é público. Pastas sensíveis
    (administrativo, contratos) são marcadas como 'restrito' explicitamente.
    """
    chave = key.lower()
    for prefixo, nivel in PREFIXOS_NIVEL_ACESSO.items():
        if prefixo in chave:
            return nivel
    return "interno"


# ── Extração de texto ─────────────────────────────────────────

def extrair_texto(key: str, dados: bytes) -> str:
    ext = extensao(key)

    if ext == "pdf":
        reader = PdfReader(BytesIO(dados))
        paginas = []
        for i, pagina in enumerate(reader.pages):
            texto = pagina.extract_text() or ""
            if texto.strip():
                paginas.append(f"[Página {i+1}]\n{texto}")
        return "\n\n".join(paginas)

    elif ext in ("docx", "doc"):
        doc = Document(BytesIO(dados))
        return "\n".join(p.text for p in doc.paragraphs if p.text.strip())

    elif ext in ("pptx", "ppt"):
        prs = Presentation(BytesIO(dados))
        slides = []
        for i, slide in enumerate(prs.slides):
            textos = [
                shape.text.strip()
                for shape in slide.shapes
                if hasattr(shape, "text") and shape.text.strip()
            ]
            if textos:
                slides.append(f"[Slide {i+1}]\n" + "\n".join(textos))
        return "\n\n".join(slides)

    elif ext in ("md", "txt"):
        return dados.decode("utf-8", errors="ignore")

    return ""


# ── Chunking ──────────────────────────────────────────────────

def chunkar(texto: str, chunk_size: int = 800, overlap: int = 100) -> list[str]:
    chunks = []
    i = 0
    while i < len(texto):
        chunk = texto[i:i + chunk_size].strip()
        if len(chunk) > 50:
            chunks.append(chunk)
        i += chunk_size - overlap
    return chunks


# ── Embedding ─────────────────────────────────────────────────

def embedar(texto: str) -> list[float]:
    # text-embedding-3-small: mais barato e melhor que o legado ada-002, e também
    # 1536 dimensões — troca direta sem mexer no VECTOR(1536) do banco.
    resp = openai_client.embeddings.create(
        input=texto,
        model=os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small"),
    )
    return resp.data[0].embedding


# ── Banco ─────────────────────────────────────────────────────

def ja_indexado(conn, caminho: str, hash_arquivo: str) -> bool:
    cur = conn.cursor()
    cur.execute(
        "SELECT hash_sha256 FROM rag.arquivos_indexados WHERE caminho = %s",
        (caminho,),
    )
    row = cur.fetchone()
    cur.close()
    return bool(row and row[0] == hash_arquivo)


def salvar_chunks(conn, chunks: list[str], key: str, tipo: str,
                  sistema: str | None, nivel_acesso: str):
    cur = conn.cursor()

    # Remove chunks antigos desse arquivo
    cur.execute("DELETE FROM rag.documentos WHERE fonte = %s", (key,))

    for chunk in chunks:
        emb = embedar(chunk)
        cur.execute(
            """
            INSERT INTO rag.documentos (fonte, tipo, sistema, conteudo, embedding, nivel_acesso, metadata)
            VALUES (%s, %s, %s, %s, %s::vector, %s, %s)
            """,
            (key, tipo, sistema, chunk, emb, nivel_acesso, '{"indexador":"worker_v1"}'),
        )

    cur.close()


def atualizar_controle(conn, caminho: str, hash_arquivo: str, tipo: str, total_chunks: int):
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO rag.arquivos_indexados (caminho, hash_sha256, tipo, total_chunks, status)
        VALUES (%s, %s, %s, %s, 'ok')
        ON CONFLICT (caminho) DO UPDATE SET
            hash_sha256     = EXCLUDED.hash_sha256,
            tipo            = EXCLUDED.tipo,
            total_chunks    = EXCLUDED.total_chunks,
            ultima_ingestao = NOW(),
            status          = 'ok'
        """,
        (caminho, hash_arquivo, tipo, total_chunks),
    )
    cur.close()


def registrar_erro(conn, caminho: str, erro: str):
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO rag.arquivos_indexados (caminho, hash_sha256, tipo, status)
        VALUES (%s, '', '', 'erro')
        ON CONFLICT (caminho) DO UPDATE SET
            status          = 'erro',
            ultima_ingestao = NOW()
        """,
        (caminho,),
    )
    cur.close()


# ── Ingestão de um arquivo ────────────────────────────────────

def indexar_arquivo(key: str, forcar: bool = False):
    log.info(f"Verificando: {key}")

    obj   = s3.get_object(Bucket=BUCKET, Key=key)
    dados = obj["Body"].read()
    h     = sha256(dados)
    conn  = get_conn()

    try:
        if not forcar and ja_indexado(conn, key, h):
            log.info(f"  Sem mudanças, pulando.")
            conn.close()
            return

        texto = extrair_texto(key, dados)
        if not texto.strip():
            log.warning(f"  Texto vazio em {key}, pulando.")
            conn.close()
            return

        chunks  = chunkar(texto)
        tipo    = extensao(key)
        sistema = detectar_sistema(key)
        nivel   = classificar_nivel_acesso(key)

        # TODO (LGPD/RDA-007): antes de indexar, varrer o conteúdo por PII (CPF, e-mail,
        # telefone) e segurar/mascarar o que não deveria virar cópia no banco. Hoje só
        # classificamos o acesso pela pasta; a detecção de PII no texto ainda falta.

        salvar_chunks(conn, chunks, key, tipo, sistema, nivel)
        atualizar_controle(conn, key, h, tipo, len(chunks))
        conn.commit()

        log.info(f"  ✓ Indexado: {len(chunks)} chunks | tipo={tipo} | sistema={sistema or '-'} | acesso={nivel}")

    except Exception as e:
        log.error(f"  ✗ Erro em {key}: {e}")
        registrar_erro(conn, key, str(e))
        conn.commit()

    finally:
        conn.close()


# ── Ingestão completa ─────────────────────────────────────────

def rodar_ingestao(forcar: bool = False, arquivo_especifico: str = None):
    inicio = datetime.now()
    log.info("=" * 60)
    log.info(f"Iniciando ingestão — forcar={forcar}")

    if arquivo_especifico:
        indexar_arquivo(arquivo_especifico, forcar=True)
    else:
        paginator = s3.get_paginator("list_objects_v2")
        total, erros = 0, 0

        for page in paginator.paginate(Bucket=BUCKET):
            for obj in page.get("Contents", []):
                key = obj["Key"]
                ext = extensao(key)
                if ext in EXTENSOES_TABULARES:
                    log.info(f"Ignorando dado tabular (vai pro Núcleo via text-to-SQL): {key}")
                    continue
                if ext not in EXTENSOES_VALIDAS:
                    continue
                try:
                    indexar_arquivo(key, forcar=forcar)
                    total += 1
                except Exception as e:
                    log.error(f"Falha geral em {key}: {e}")
                    erros += 1

        duracao = (datetime.now() - inicio).total_seconds()
        log.info(f"Concluído: {total} arquivos processados, {erros} erros — {duracao:.1f}s")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="FNP Ingestor")
    parser.add_argument("--force", action="store_true", help="Reindexar tudo")
    parser.add_argument("--arquivo", type=str, help="Indexar um arquivo específico (key do Spaces)")
    args = parser.parse_args()

    rodar_ingestao(forcar=args.force, arquivo_especifico=args.arquivo)
