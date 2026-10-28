-- ============================================================
-- Schema do CASD-Calendário — rodar inteiro no SQL Editor do Supabase
-- (Project > SQL Editor > New query > colar tudo > Run)
-- ============================================================

-- ========== 1. FRENTES ==========
create table frentes (
  id text primary key,
  nome text not null
);
insert into frentes (id, nome) values
  ('vest','CASDvest'), ('inho','CASDinho'), ('ext','Extensão');

-- ========== 2. DEPARTAMENTOS (catálogo de siglas) ==========
create table departamentos (
  id text primary key,
  nome text not null
);
insert into departamentos (id, nome) values
  ('rh','Recursos Humanos'), ('des','Desenvolvimento'), ('ens','Ensino'),
  ('mkt','Marketing'), ('cap','Captação'), ('fin','Financeiro'), ('ges','Gestão');

-- ========== 3. TIMES (combinação concreta frente × departamento) ==========
create table times (
  id uuid primary key default gen_random_uuid(),
  frente_id text not null references frentes(id),
  departamento_id text not null references departamentos(id),
  unique (frente_id, departamento_id)
);
insert into times (frente_id, departamento_id) values
  ('vest','rh'), ('vest','des'), ('vest','ens'),
  ('inho','rh'), ('inho','des'), ('inho','ens'),
  ('ext','mkt'), ('ext','cap'), ('ext','fin'), ('ext','ges');

-- ========== 4. PERFIS (1 linha por usuário autenticado) ==========
create table perfis (
  id uuid primary key references auth.users(id) on delete cascade,
  nome_exibicao text not null,
  cargo text not null check (cargo in ('exe','dir','membro')) default 'membro',
  time_principal_id uuid references times(id),  -- null = executivo (nível esfera, sem time fixo)
  criado_em timestamptz not null default now()
);

-- ========== 5. EVENTOS/TAREFAS (tabela única) ==========
create table eventos (
  id uuid primary key default gen_random_uuid(),
  tipo text not null check (tipo in ('evento','tarefa')) default 'evento',
  titulo text not null,
  descricao text,
  data date not null,
  data_fim date,
  categoria text check (categoria in ('marco','prova','institucional','destaque','geral')) default 'geral',
  visibilidade text not null check (visibilidade in ('publico','privado')) default 'publico',
  time_id uuid references times(id),
  dono_id uuid not null references perfis(id),
  responsavel_id uuid references perfis(id),
  status text check (status in ('pendente','concluida','atrasada')),
  meta_ref text,  -- gancho pra integrar depois com o sistema de metas/OKRs
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index on eventos (data);
create index on eventos (time_id);
create index on eventos (dono_id);

-- ========== 6. PREFERÊNCIAS DE FILTRO POR USUÁRIO (não é RLS, é UI) ==========
create table filtros_usuario (
  usuario_id uuid not null references perfis(id) on delete cascade,
  time_id uuid not null references times(id) on delete cascade,
  primary key (usuario_id, time_id)
);

-- ========== 7. MARCAÇÕES MANUAIS DE DIA (vermelho/verde/amarelo) ==========
-- feature já existente no protótipo (conflito/janela boa/atenção) — compartilhada,
-- não é dado pessoal, então não precisa de dono.
create table flags (
  data date primary key,
  cor text not null check (cor in ('vermelho','verde','amarelo'))
);

-- ========== 8. HORÁRIO PADRÃO DE AULA (modelo editável, compartilhado) ==========
create table horario (
  doc_id text primary key,  -- ex: 'seg-t1'
  aulas jsonb not null default '{}'::jsonb
);

-- ============================================================
-- RLS — leitura: público OU dono/responsável; cargo/depto nunca bloqueiam leitura.
-- escrita: dono sempre edita o seu; diretor edita do time que dirige;
-- executivo edita qualquer coisa não-privada.
-- ============================================================

alter table frentes enable row level security;
alter table departamentos enable row level security;
alter table times enable row level security;
alter table perfis enable row level security;
alter table eventos enable row level security;
alter table filtros_usuario enable row level security;
alter table flags enable row level security;
alter table horario enable row level security;

-- catálogos: leitura livre pra qualquer autenticado
create policy "catalogos leitura" on frentes for select using (auth.role() = 'authenticated');
create policy "catalogos leitura" on departamentos for select using (auth.role() = 'authenticated');
create policy "catalogos leitura" on times for select using (auth.role() = 'authenticated');

-- perfis: todo mundo autenticado vê nome/cargo/time de todo mundo (é metadado interno, não é privado)
create policy "perfis leitura" on perfis for select using (auth.role() = 'authenticated');
create policy "perfis insert propria" on perfis for insert with check (id = auth.uid());
create policy "perfis update propria" on perfis for update using (id = auth.uid());
create policy "perfis update executivo" on perfis for update using (
  exists (select 1 from perfis p where p.id = auth.uid() and p.cargo = 'exe')
);

-- eventos: leitura = público OU dono OU responsável
create policy "eventos leitura" on eventos for select using (
  visibilidade = 'publico' or dono_id = auth.uid() or responsavel_id = auth.uid()
);
create policy "eventos insert" on eventos for insert with check (dono_id = auth.uid());
create policy "eventos update dono" on eventos for update using (dono_id = auth.uid());
create policy "eventos delete dono" on eventos for delete using (dono_id = auth.uid());
create policy "eventos update diretor do time" on eventos for update using (
  time_id in (select time_principal_id from perfis where id = auth.uid() and cargo = 'dir')
);
create policy "eventos delete diretor do time" on eventos for delete using (
  time_id in (select time_principal_id from perfis where id = auth.uid() and cargo = 'dir')
);
create policy "eventos update executivo" on eventos for update using (
  visibilidade = 'publico' and exists (select 1 from perfis where id = auth.uid() and cargo = 'exe')
);
create policy "eventos delete executivo" on eventos for delete using (
  visibilidade = 'publico' and exists (select 1 from perfis where id = auth.uid() and cargo = 'exe')
);

-- filtros_usuario: cada um só lê/escreve os próprios filtros
create policy "filtros leitura propria" on filtros_usuario for select using (usuario_id = auth.uid());
create policy "filtros insert propria" on filtros_usuario for insert with check (usuario_id = auth.uid());
create policy "filtros delete propria" on filtros_usuario for delete using (usuario_id = auth.uid());

-- flags/horario: compartilhados, qualquer autenticado lê/escreve (não são dados pessoais)
create policy "flags leitura" on flags for select using (auth.role() = 'authenticated');
create policy "flags escrita" on flags for insert with check (auth.role() = 'authenticated');
create policy "flags update" on flags for update using (auth.role() = 'authenticated');
create policy "flags delete" on flags for delete using (auth.role() = 'authenticated');

create policy "horario leitura" on horario for select using (auth.role() = 'authenticated');
create policy "horario escrita" on horario for insert with check (auth.role() = 'authenticated');
create policy "horario update" on horario for update using (auth.role() = 'authenticated');
