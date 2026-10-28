# Como colocar o Calendário CASD no ar

Dois arquivos deste projeto: `schema.sql` (banco) e `index.html` (o site). Siga a ordem abaixo.

## 1. Criar o projeto no Supabase

1. Crie uma conta em https://supabase.com e um projeto novo (região `São Paulo (sa-east-1)` se disponível).
2. No menu lateral, abra **SQL Editor** → **New query**, cole todo o conteúdo de `schema.sql` e clique em **Run**.
   - Se der erro "already exists", é porque você já rodou antes — pode ignorar ou apagar as tabelas e rodar de novo.
3. Vá em **Authentication → Providers** e habilite o **Google**. Você vai precisar criar um "OAuth Client ID" no [Google Cloud Console](https://console.cloud.google.com/apis/credentials) (tipo "Web application") e colar o Client ID/Secret aqui — o próprio painel do Supabase mostra o passo a passo e a "Callback URL" que você precisa cadastrar no Google.
4. Vá em **Project Settings → API** e copie dois valores:
   - **Project URL**
   - **anon public key**

## 2. Configurar o `index.html`

Abra `index.html`, procure por (perto do topo do `<script>`):

```js
const SUPABASE_URL = 'COLE_AQUI_A_PROJECT_URL';
const SUPABASE_ANON_KEY = 'COLE_AQUI_A_ANON_PUBLIC_KEY';
```

Troque pelos dois valores que você copiou no passo 1.4. É normal e seguro essas duas strings ficarem visíveis no código — quem protege os dados de verdade são as regras (RLS) que já estão no `schema.sql`, nunca a chave em si.

Abra o `index.html` localmente (duas opções):
- Clique duas vezes nele (funciona pra ver o visual, mas o login com Google **não funciona** em `file://` — precisa ser servido por http).
- Rode um servidor local simples, ex. `npx serve .` dentro da pasta, e abra `http://localhost:3000`.

## 3. Publicar no GitHub Pages

```
git init
git add index.html schema.sql SETUP.md
git commit -m "Primeira versão do calendário CASD"
```

Crie um repositório novo no GitHub (pode ser público ou privado — Pages grátis exige público, a menos que você tenha GitHub Pro), depois:

```
git remote add origin https://github.com/SEU_USUARIO/SEU_REPO.git
git push -u origin main
```

No GitHub: **Settings → Pages → Source: branch `main`, pasta `/ (root)`**. Depois de alguns minutos o site fica em `https://SEU_USUARIO.github.io/SEU_REPO/`.

## 4. Fechar o ciclo do login

Volte no Supabase → **Authentication → URL Configuration** e adicione a URL do GitHub Pages (`https://SEU_USUARIO.github.io/SEU_REPO/`) na lista de **Redirect URLs** permitidas. Sem isso o login com Google completa mas o Supabase recusa redirecionar de volta pro site.

## 5. Dar cargo/time pra cada pessoa

Por padrão, todo mundo que loga pela primeira vez entra como `membro` sem time. Pra promover alguém a diretor/executivo ou linkar ao time certo, abra o Supabase → **Table Editor → perfis** e edite as colunas `cargo` (`exe`/`dir`/`membro`) e `time_principal_id` manualmente (não tem UI pra isso ainda — é Fase 2).
