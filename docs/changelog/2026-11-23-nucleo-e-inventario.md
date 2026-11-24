# 2026-11-23 — Núcleo multi-tenant e inventario

## Qué se hizo
- Migración `nucleo_multitenant`: tenants, miembros, roles, funciones es_miembro/tiene_rol/crear_tenant, RLS.
- Migración `inventario_lotes`: PostGIS, proyectos, manzanas, lotes, estados, precio_total calculado, RLS.

## Por qué
- Primero los datos y la seguridad, después las pantallas.
- El inventario de lotes es el corazón del primer producto vendible.
- Probado: una empresa no ve ni modifica datos de otra.
