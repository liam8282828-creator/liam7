create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  phone text not null default '',
  expires_at timestamptz not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.licenses (
  id uuid primary key default gen_random_uuid(),
  license_key text not null unique,
  expires_at timestamptz not null,
  is_active boolean not null default true,
  user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.licenses enable row level security;

create policy "Users can read their own profile"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

insert into public.licenses (license_key, expires_at)
values ('MOON-TEST-2026', now() + interval '30 days')
on conflict (license_key) do nothing;
