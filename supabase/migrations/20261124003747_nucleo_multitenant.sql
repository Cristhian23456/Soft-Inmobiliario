create type public.tenant_tipo as enum ('inmobiliaria', 'estudio', 'tienda');

create type public.rol_tenant as enum (
  'dueno', 'gerente', 'vendedor', 'cobranza', 'arquitecto', 'maestro', 'encargado'
);
create table public.tenants (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null check (length(trim(nombre)) > 0),
  tipo       public.tenant_tipo not null default 'inmobiliaria',
  ruc        text,
  creado_en  timestamptz not null default now()
);

create table public.miembros (
  tenant_id  uuid not null references public.tenants (id) on delete cascade,
  usuario_id uuid not null references auth.users (id) on delete cascade,
  rol        public.rol_tenant not null,
  creado_en  timestamptz not null default now(),
  primary key (tenant_id, usuario_id)
);

create index miembros_usuario_idx on public.miembros (usuario_id);
create or replace function public.es_miembro(p_tenant uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.miembros m
    where m.tenant_id = p_tenant and m.usuario_id = (select auth.uid())
  );
$$;

create or replace function public.tiene_rol(p_tenant uuid, p_roles public.rol_tenant[])
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.miembros m
    where m.tenant_id = p_tenant
      and m.usuario_id = (select auth.uid())
      and m.rol = any (p_roles)
  );
$$;

create or replace function public.crear_tenant(
  p_nombre text,
  p_tipo public.tenant_tipo default 'inmobiliaria'
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Se requiere un usuario autenticado';
  end if;

  insert into public.tenants (nombre, tipo) values (p_nombre, p_tipo) returning id into v_id;
  insert into public.miembros (tenant_id, usuario_id, rol) values (v_id, (select auth.uid()), 'dueno');
  return v_id;
end;
$$;

revoke execute on function public.crear_tenant(text, public.tenant_tipo) from anon, public;
grant execute on function public.crear_tenant(text, public.tenant_tipo) to authenticated;
alter table public.tenants  enable row level security;
alter table public.miembros enable row level security;

create policy tenants_select on public.tenants
  for select to authenticated using (public.es_miembro(id));

create policy tenants_update on public.tenants
  for update to authenticated
  using (public.tiene_rol(id, array['dueno']::public.rol_tenant[]))
  with check (public.tiene_rol(id, array['dueno']::public.rol_tenant[]));

create policy miembros_select on public.miembros
  for select to authenticated using (public.es_miembro(tenant_id));

create policy miembros_write on public.miembros
  for all to authenticated
  using (public.tiene_rol(tenant_id, array['dueno', 'gerente']::public.rol_tenant[]))
  with check (public.tiene_rol(tenant_id, array['dueno', 'gerente']::public.rol_tenant[]));