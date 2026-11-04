-- 1) Copie tout ce fichier dans Supabase > SQL Editor > New query, puis clique sur Run.

-- Table unique qui stocke toutes les données de l'app
create table if not exists public.docs (
  collection text not null,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (collection, id)
);

-- Liste des e-mails autorisés à utiliser l'app
create table if not exists public.allowed_emails (
  email text primary key
);

-- Vérifie si la personne connectée fait partie du groupe
create or replace function public.is_member()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.allowed_emails
    where lower(email) = lower(auth.jwt() ->> 'email')
  );
$$;

alter table public.docs enable row level security;
alter table public.allowed_emails enable row level security;

drop policy if exists "membres lisent" on public.docs;
drop policy if exists "membres ajoutent" on public.docs;
drop policy if exists "membres modifient" on public.docs;
drop policy if exists "membres suppriment" on public.docs;
create policy "membres lisent" on public.docs for select to authenticated using (public.is_member());
create policy "membres ajoutent" on public.docs for insert to authenticated with check (public.is_member());
create policy "membres modifient" on public.docs for update to authenticated using (public.is_member()) with check (public.is_member());
create policy "membres suppriment" on public.docs for delete to authenticated using (public.is_member());

-- Temps réel : tout le monde voit les changements en direct
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;

-- 2) Les membres du groupe : ajoute une ligne par e-mail
insert into public.allowed_emails (email) values
  ('meriem.elaita@gmail.com')
  -- , ('email.de.itzel@exemple.com')
  -- , ('email.de.rania@exemple.com')
  -- , ('email.de.paul@exemple.com')
on conflict do nothing;
