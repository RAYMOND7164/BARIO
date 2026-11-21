-- =====================================================================
-- BARIO · Script 12 · Activer / desactiver le role des serveuses
-- A lancer une fois dans Supabase > SQL Editor (peut etre relance sans danger).
--   - Reglage par club (settings.waitress_mode), active par defaut.
--   - Desactive : les serveuses ne peuvent plus rien faire, le gerant prend
--     lui-meme les commandes.
--   - Seul le patron peut changer ce reglage.
-- =====================================================================

alter table public.settings add column if not exists waitress_mode boolean not null default true;

create or replace function public._require_member()
returns uuid language plpgsql stable security definer set search_path = public as $$
declare v uuid; v_role text; v_club uuid;
begin
  select id, role, club_id into v, v_role, v_club
    from public.members where user_id = auth.uid() and active limit 1;
  if v is null then raise exception 'Compte non autorise'; end if;
  -- Mode serveuses desactive par le patron : seul le gerant prend les commandes.
  if v_role = 'serveuse' and not coalesce(
       (select waitress_mode from public.settings where club_id = v_club), true) then
    raise exception 'Le role des serveuses est desactive : le gerant prend les commandes';
  end if;
  return v;
end $$;

create or replace function public._garde_mode_serveuses()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.waitress_mode is distinct from old.waitress_mode
     and auth.uid() is not null and not public.is_patron() then
    raise exception 'Seul le patron peut activer ou desactiver le role des serveuses';
  end if;
  return new;
end $$;

drop trigger if exists settings_mode_serveuses on public.settings;
create trigger settings_mode_serveuses before update on public.settings
  for each row execute function public._garde_mode_serveuses();

revoke execute on function public._garde_mode_serveuses() from public, anon;

notify pgrst, 'reload schema';
