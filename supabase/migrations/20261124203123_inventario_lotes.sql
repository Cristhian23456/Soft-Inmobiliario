create extension if not exists postgis with schema extensions;

create type public.lote_estado as enum (
  'disponible', 'apartado', 'reservado', 'negociacion', 'vendido', 'escriturado'
);
create table public.proyectos (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  nombre        text not null check (length(trim(nombre)) > 0),
  descripcion   text,
  ubicacion     extensions.geography(point, 4326),
  area_total_m2 numeric(12, 2) check (area_total_m2 > 0),
  campos_extra  jsonb not null default '{}'::jsonb,
  creado_en     timestamptz not null default now(),
  unique (id, tenant_id)
);

create index proyectos_tenant_idx on public.proyectos (tenant_id);

create table public.manzanas (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null,
  proyecto_id uuid not null,
  codigo      text not null,
  creado_en   timestamptz not null default now(),
  unique (id, tenant_id),
  unique (proyecto_id, codigo),
  foreign key (proyecto_id, tenant_id)
    references public.proyectos (id, tenant_id) on delete cascade
);

create index manzanas_tenant_idx on public.manzanas (tenant_id);
create table public.lotes (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null,
  proyecto_id    uuid not null,
  manzana_id     uuid,
  codigo         text not null,
  area_m2        numeric(10, 2) not null check (area_m2 > 0),
  precio_m2      numeric(10, 2) not null check (precio_m2 >= 0),
  precio_total   numeric(14, 2) generated always as (round(area_m2 * precio_m2, 2)) stored,
  estado         public.lote_estado not null default 'disponible',
  apartado_hasta timestamptz,
  poligono       extensions.geometry(polygon, 4326),
  campos_extra   jsonb not null default '{}'::jsonb,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (proyecto_id, codigo),
  foreign key (proyecto_id, tenant_id)
    references public.proyectos (id, tenant_id) on delete cascade,
  foreign key (manzana_id, tenant_id)
    references public.manzanas (id, tenant_id) on delete set null (manzana_id),
  check (estado <> 'apartado' or apartado_hasta is not null)
);

create index lotes_tenant_idx   on public.lotes (tenant_id);
create index lotes_proyecto_idx on public.lotes (proyecto_id, estado);
create index lotes_poligono_idx on public.lotes using gist (poligono);

create or replace function public.tocar_actualizado_en()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

create trigger lotes_actualizado_en
  before update on public.lotes
  for each row execute function public.tocar_actualizado_en();

  alter table public.proyectos enable row level security;
alter table public.manzanas  enable row level security;
alter table public.lotes     enable row level security;

create policy proyectos_select on public.proyectos
  for select to authenticated using (public.es_miembro(tenant_id));
create policy proyectos_write on public.proyectos
  for all to authenticated
  using (public.tiene_rol(tenant_id, array['dueno', 'gerente']::public.rol_tenant[]))
  with check (public.tiene_rol(tenant_id, array['dueno', 'gerente']::public.rol_tenant[]));

create policy manzanas_select on public.manzanas
  for select to authenticated using (public.es_miembro(tenant_id));
create policy manzanas_write on public.manzanas
  for all to authenticated
  using (public.tiene_rol(tenant_id, array['dueno', 'gerente']::public.rol_tenant[]))
  with check (public.tiene_rol(tenant_id, array['dueno', 'gerente']::public.rol_tenant[]));

create policy lotes_select on public.lotes
  for select to authenticated using (public.es_miembro(tenant_id));
create policy lotes_insert on public.lotes
  for insert to authenticated
  with check (public.tiene_rol(tenant_id, array['dueno', 'gerente']::public.rol_tenant[]));
create policy lotes_update on public.lotes
  for update to authenticated
  using (public.tiene_rol(tenant_id, array['dueno', 'gerente', 'vendedor']::public.rol_tenant[]))
  with check (public.tiene_rol(tenant_id, array['dueno', 'gerente', 'vendedor']::public.rol_tenant[]));
create policy lotes_delete on public.lotes
  for delete to authenticated
  using (public.tiene_rol(tenant_id, array['dueno', 'gerente']::public.rol_tenant[]));