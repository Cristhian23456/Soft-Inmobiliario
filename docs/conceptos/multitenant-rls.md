# Conceptos: multi-tenant y seguridad en la base de datos

- **Multi-tenant:** una app atiende a varias empresas; cada fila lleva tenant_id.
- **RLS (Row Level Security):** PostgreSQL filtra filas por usuario. `using` = qué filas puedo ver/tocar; `with check` = qué filas puedo guardar.
- **auth.uid():** id del usuario con sesión, tomado del token (JWT).
- **security definer + search_path = '':** la función corre con permisos de su dueño y no se puede engañar con objetos falsos.
- **FK compuesta (id, tenant_id):** la relación exige que el padre sea de la misma empresa.
- **Columna generada:** valor calculado por la base de datos (precio_total), nunca desincronizado.
- **CHECK:** regla de negocio en la base de datos (apartado requiere fecha).
- **Trigger:** código que se ejecuta solo ante un evento (actualizar fecha).
- **PostGIS / índice GiST:** formas geográficas y búsquedas espaciales rápidas.
- **Migraciones:** cambios versionados; `db reset` reconstruye todo desde cero.
