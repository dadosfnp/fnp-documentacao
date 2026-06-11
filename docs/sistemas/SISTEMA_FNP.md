# Sistema FNP — Documentação para a Base de Conhecimento

Plataforma web de gestão institucional da Frente Nacional de Prefeitas e Prefeitos.
Cadastro de pessoas, municípios, adimplência, engajamento, eventos, missões,
recepção de visitas e mala direta. Conformidade com a LGPD nível 2.

---

## O que é e para que serve

O Sistema FNP é o sistema central de gestão da instituição. Ele centraliza:

- Cadastro de **prefeitos, secretários e equipe interna**
- Dados de **municípios filiados** e seus vínculos com pessoas
- Controle de **adimplência** (pagamentos anuais por município)
- **Engajamento** dos municípios (pontuação por participação em eventos e missões)
- **Eventos** institucionais e registros de participação
- **Missões** e delegações
- **Presença** e visitas à sede da FNP
- **Mala direta** e comunicação institucional
- **Relatórios e painéis** de gestão

---

## Onde o sistema roda

| Ambiente | Detalhe |
|----------|---------|
| Produção | DigitalOcean App Platform |
| Banco de dados | DO Managed PostgreSQL 16 |
| Domínio | `sistema.fnp.org.br` |
| Repositório | GitHub privado FNP |

---

## Tecnologias utilizadas

| Componente | Tecnologia |
|------------|------------|
| Backend | Django 5.x com Python 3.12 |
| Banco de dados | PostgreSQL 16 (DigitalOcean Managed) |
| Frontend | HTMX + Tailwind CSS + Alpine.js |
| Painel administrativo | Django Unfold |
| Autenticação | django-allauth (Google OAuth) + django-otp (2FA TOTP) |
| Proteção contra força bruta | django-axes |
| Arquivos estáticos | WhiteNoise |
| Arquitetura | 100% síncrona — sem Celery, sem Redis |

---

## Estrutura de aplicações

```
sistema-fnp/
├── configuracao/          # Configurações (base, local, producao) + urls
├── aplicacoes/
│   ├── nucleo/            # Perfil, autenticação, LGPD, middlewares, permissões
│   ├── cadastro/          # Pessoa, Município, VínculoMunicípio
│   ├── adimplencia/       # Pagamentos anuais e status por município
│   ├── engajamento/       # Pontuação e nível dos municípios
│   ├── eventos/           # Eventos institucionais e participações
│   ├── instancias/        # Espaços de diálogo federativo
│   ├── projetos/          # Projetos institucionais
│   ├── missoes/           # Missões e delegações
│   ├── atividades/        # Reuniões e atividades por instância
│   ├── documentos/        # Anexos e biblioteca de arquivos
│   ├── presenca/          # Visitas, pré-credenciamento, presença universal
│   ├── comunicacao/       # Templates de e-mail e mala direta
│   ├── dicionario/        # Glossário do sistema
│   └── relatorios/        # Painéis e exportações
├── templates/             # Templates globais e por aplicação
├── estaticos/             # CSS e JavaScript
└── documentacao/          # DPIA-RoT, configuração de autenticação, RDAs
```

---

## Como os dados se relacionam (modelo de domínio)

```
Pessoa
  └── tem um ou mais VínculoMunicípio
        └── tipos: prefeito | secretário | assessor

Município
  ├── tem registros anuais de Adimplência
  └── tem pontuação de Engajamento

Evento
  └── gera Participação
        └── impacta automaticamente o Engajamento do município

Presença
  └── é universal — pode ser anexada a Evento, Missão ou Atividade
```

A pontuação de engajamento é **recalculada automaticamente** via signals do Django ao registrar qualquer participação.

---

## Autenticação e controle de acesso

### Como o login funciona

- Login com Google `@fnp.org.br` → aprovado automaticamente, sem 2FA obrigatório
- Login com Google (outros domínios) → entra como "pendente", exige 2FA, validade de 90 dias
- Login local também disponível

### Tipos de perfil

| Tipo | O que pode fazer |
|------|-----------------|
| `visualizador` | Leitura geral do sistema |
| `editor` | Leitura e escrita |
| `admin` | Tudo, incluindo gestão de usuários |
| `prefeito` | Acesso restrito ao portal `/portal/` |
| `externo` | Acesso limitado com 2FA obrigatório |

### Regra fundamental de permissões

Sempre usar o serviço centralizado — nunca fazer checagens diretas no código:

```python
from aplicacoes.nucleo.servicos.permissoes import pode_ver
pode_ver(user, obj)
```

### Ordem dos middlewares (ordem importa)

1. `AuthenticationMiddleware` (Django)
2. `OTPMiddleware` (injeta verificação do 2FA)
3. `AccountMiddleware` (allauth)
4. `IsolarPortalPrefeitoMiddleware` — perfis "prefeito" ficam só em `/portal/`
5. `BloquearAcessoExpiradoMiddleware` — pendente/expirado vai para aguardando aprovação
6. `Exigir2FAMiddleware` — redireciona quem precisa de 2FA
7. `ExigirAceiteTermoMiddleware` — redireciona quem não aceitou o termo
8. `AxesMiddleware` (último, para capturar tentativas de login)

---

## Conformidade com a LGPD

- Todos os acessos a dados pessoais sensíveis são registrados em log de auditoria
- CPFs, telefones e e-mails de prefeitos nunca aparecem em logs, seeds ou exemplos de código
- Purga automática: visitas com mais de 5 anos são anonimizadas; logs com mais de 2 anos são deletados
- Pedidos de exclusão de dados são tratados via `SolicitacaoExclusao` (Art. 18, VI da LGPD)
- Encarregado de Dados (DPO): `dpo@fnp.org.br`

---

## Comandos disponíveis

| Comando | O que faz |
|---------|-----------|
| `python manage.py runserver` | Inicia o servidor de desenvolvimento na porta 8000 |
| `python manage.py test aplicacoes/` | Executa a suíte de testes (aproximadamente 25 testes) |
| `python manage.py makemigrations` | Gera migrações a partir dos modelos |
| `python manage.py migrate` | Aplica migrações no banco de dados |
| `python manage.py createsuperuser` | Cria uma conta de administrador |
| `python manage.py configurar_google_oauth` | Configura o OAuth do Google com base no `.env` |
| `python manage.py purgar_dados_antigos` | Purga e anonimiza dados conforme política LGPD (rodar mensalmente) |

---

## Convenções de desenvolvimento

- Todo código de domínio em **português brasileiro** — aplicações, modelos, campos, URLs, variáveis de negócio
- Nomes técnicos do Django permanecem em inglês (models.py, views.py, urls.py etc.)
- Cada aplicação fica em `aplicacoes/<nome>/` com seus próprios arquivos de modelo, view, url, form, admin e testes
- Templates seguem o padrão `templates/<app>/<acao>_<entidade>.html`
- Fragmentos HTMX ficam em `templates/<app>/parciais/`
- Lógica de negócio que não pertence ao modelo nem à view fica em `aplicacoes/<app>/servicos/`
- Importações absolutas: `from aplicacoes.cadastro.models import Pessoa`

### O que nunca fazer

- Nunca usar Docker — desenvolvimento 100% local, deploy gerenciado
- Nunca instalar Celery ou Redis — tarefas são síncronas; jobs periódicos via Cron do DO
- Nunca usar chave primária sequencial — sempre UUID via `ModeloBase`
- Nunca commitar o arquivo `.env`
- Nunca incluir dados reais em fixtures ou exemplos de código

---

## Variáveis de ambiente obrigatórias em produção

| Variável | Para que serve |
|----------|---------------|
| `DJANGO_SETTINGS_MODULE` | Deve ser `configuracao.producao` |
| `SECRET_KEY` | Mínimo 50 caracteres aleatórios |
| `DATABASE_URL` | String de conexão do DO Managed Postgres com `?sslmode=require` |
| `ALLOWED_HOSTS` | Lista de domínios separados por vírgula |
| `GOOGLE_OAUTH_CLIENT_ID` | Do Google Cloud Console |
| `GOOGLE_OAUTH_CLIENT_SECRET` | Do Google Cloud Console |
| `EMAIL_HOST_USER` | SMTP do Google Workspace para mala direta |
| `EMAIL_HOST_PASSWORD` | SMTP do Google Workspace para mala direta |
| `SECURE_SSL_REDIRECT` | `True` em produção |

---

## Perguntas frequentes sobre o sistema

**P: Onde ficam os dados dos municípios filiados?**
R: Na aplicação `cadastro`, modelo `Municipio`, com vínculos a prefeitos e secretários via `VinculoMunicipio`.

**P: Como funciona a pontuação de engajamento?**
R: É calculada automaticamente via signals do Django ao registrar participação em evento, missão ou atividade. A aplicação responsável é `engajamento`.

**P: Como verificar se um município está adimplente?**
R: Via aplicação `adimplencia`, que armazena registros anuais de pagamento por município.

**P: Onde ficam os registros de visitas à FNP?**
R: Na aplicação `presenca`, que usa `GenericForeignKey` para ser anexada a qualquer entidade.

**P: Como funciona o credenciamento de eventos?**
R: Também via aplicação `presenca`, com pré-credenciamento e registro de presença universal.

**P: O sistema envia e-mails?**
R: Sim, via aplicação `comunicacao`. Usa SMTP do Google Workspace. Os templates de mala direta são gerenciados lá.

**P: Como adicionar um usuário externo?**
R: O usuário faz login com Google, entra como "pendente", e o administrador aprova em `/admin/nucleo/perfil/`. Domínios `@fnp.org.br` são aprovados automaticamente.

**P: O que acontece quando uma conta expira?**
R: O `BloquearAcessoExpiradoMiddleware` redireciona automaticamente para a tela de aguardando aprovação.

**P: Onde fica a documentação técnica mais detalhada?**
R: Na pasta `documentacao/` do repositório do sistema: `autenticacao-setup.md`, `producao-readiness.md` e `DPIA-RoT.md`.

---

## Responsáveis

| Papel | Contato |
|-------|---------|
| Desenvolvedor principal | Pedro Ivo — pedro.machado@fnp.org.br |
| Encarregado de Dados (DPO) | dpo@fnp.org.br |

---

## Histórico relevante

| Data | Mudança |
|------|---------|
| 2025 | Migração para DigitalOcean (App Platform + Managed Postgres) |
| 2025 | Implementação LGPD nível 2 (OAuth + 2FA + ACL por objeto + auditoria de leitura) |
| 2025 | Aplicação `presenca` unificada com GenericForeignKey |
