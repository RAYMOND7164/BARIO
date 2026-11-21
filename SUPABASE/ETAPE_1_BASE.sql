-- BARIO · ETAPE 1 · Base complete (scripts 01 a 06, 08, 10, 11 reunis)
-- A coller en entier dans Supabase > SQL Editor, puis Run. Peut etre relance sans danger.

-- ===== 01_tables.sql =====
-- =====================================================================
-- BARIO · Script 01 · Les tables
-- A coller en entier dans Supabase > SQL Editor > New query, puis "Run".
-- Montants en FCFA (nombres entiers).
--
-- Bario est multi-clients.
-- Chaque boite de nuit est un "club" isole. La colonne club_id, presente
-- sur chaque table, dit a quel club appartient la ligne. Un club ne voit
-- jamais les donnees d'un autre (voir script 02).
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- Les clubs (les clients de Bario). Un client = un club.
-- Le patron qui cree le compte en est le proprietaire (owner_user_id).
-- ---------------------------------------------------------------------
create table if not exists public.clubs (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  owner_user_id  uuid references auth.users(id),
  phone          text,
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Reglages du club (une seule ligne par club)
-- ---------------------------------------------------------------------
create table if not exists public.settings (
  id               uuid primary key default gen_random_uuid(),
  club_id          uuid not null unique references public.clubs(id) on delete cascade,
  club_name        text not null default 'Ma boite de nuit',
  phone            text,
  ticket_header    text not null default 'MA BOITE',
  ticket_footer    text not null default 'Merci de votre visite',
  night_start_hour int  not null default 18 check (night_start_hour between 0 and 23),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- L'equipe : patron, gerant (caissier), serveuses
-- L'identifiant (login) est unique a l'interieur d'un club.
-- ---------------------------------------------------------------------
create table if not exists public.members (
  id            uuid primary key default gen_random_uuid(),
  club_id       uuid not null references public.clubs(id) on delete cascade,
  user_id       uuid unique references auth.users(id) on delete set null,
  login         text not null check (login ~ '^[a-z0-9._-]{3,30}$'),
  role          text not null check (role in ('patron', 'gerant', 'serveuse')),
  display_name  text not null,
  phone         text,
  active        boolean not null default true,
  created_at    timestamptz not null default now(),
  unique (club_id, login)
);
create index if not exists members_club_idx on public.members (club_id);

-- ---------------------------------------------------------------------
-- Les tables du club
-- ---------------------------------------------------------------------
create table if not exists public.club_tables (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  name        text not null,
  zone        text not null default 'salle' check (zone in ('salle', 'vip', 'comptoir', 'terrasse')),
  is_fixed    boolean not null default true,
  active      boolean not null default true,
  sort_order  int not null default 0,
  created_by  uuid references public.members(id),
  created_at  timestamptz not null default now(),
  unique (club_id, name)
);

-- ---------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------
create table if not exists public.categories (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  name        text not null,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  unique (club_id, name)
);

create table if not exists public.products (
  id              uuid primary key default gen_random_uuid(),
  club_id         uuid not null references public.clubs(id) on delete cascade,
  category_id     uuid references public.categories(id),
  name            text not null,
  sale_price      int  not null check (sale_price >= 0),
  purchase_price  int  not null default 0 check (purchase_price >= 0),
  track_stock     boolean not null default true,   -- non pour les cocktails
  min_stock       int  not null default 0 check (min_stock >= 0),
  active          boolean not null default true,
  sort_order      int  not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (club_id, category_id, name)
);
create index if not exists products_club_idx on public.products (club_id);

create table if not exists public.suppliers (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  name        text not null,
  phone       text,
  note        text,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Soirees, notes, boissons, paiements
-- ---------------------------------------------------------------------
create table if not exists public.nights (
  id               uuid primary key default gen_random_uuid(),
  club_id          uuid not null references public.clubs(id) on delete cascade,
  status           text not null default 'open' check (status in ('open', 'closed')),
  opened_by        uuid references public.members(id),
  opened_at        timestamptz not null default now(),
  opening_float    int not null default 0 check (opening_float >= 0),
  closed_by        uuid references public.members(id),
  closed_at        timestamptz,
  expected_cash    int,
  expected_momo    int,
  counted_cash     int,
  counted_momo     int,
  difference_cash  int,
  difference_momo  int,
  note             text
);
-- une seule soiree ouverte a la fois, PAR CLUB
create unique index if not exists nights_one_open on public.nights (club_id) where status = 'open';
create index if not exists nights_club_idx on public.nights (club_id);

create table if not exists public.tabs (
  id             uuid primary key default gen_random_uuid(),
  club_id        uuid not null references public.clubs(id) on delete cascade,
  night_id       uuid not null references public.nights(id),
  table_id       uuid not null references public.club_tables(id),
  waitress_id    uuid not null references public.members(id),
  status         text not null default 'open' check (status in ('open', 'to_pay', 'paid', 'cancelled')),
  ticket_number  bigint,
  total          int not null default 0,
  paid_amount    int not null default 0,
  opened_at      timestamptz not null default now(),
  requested_at   timestamptz,
  paid_at        timestamptz,
  cashier_id     uuid references public.members(id),
  cancelled_by   uuid references public.members(id),
  cancel_reason  text,
  unique (club_id, ticket_number)
);
-- une seule note en cours par table
create unique index if not exists tabs_one_active_per_table
  on public.tabs (table_id) where status in ('open', 'to_pay');
create index if not exists tabs_night_idx on public.tabs (night_id);
create index if not exists tabs_waitress_idx on public.tabs (waitress_id);
create index if not exists tabs_club_idx on public.tabs (club_id);

create table if not exists public.tab_items (
  id              uuid primary key default gen_random_uuid(),
  club_id         uuid not null references public.clubs(id) on delete cascade,
  tab_id          uuid not null references public.tabs(id) on delete cascade,
  product_id      uuid not null references public.products(id),
  product_name    text not null,                 -- nom fige au moment de la commande
  quantity        int  not null check (quantity > 0),
  unit_price      int  not null check (unit_price >= 0),  -- prix fige
  cost_price      int  not null default 0,               -- cout fige (cache aux serveuses)
  status          text not null default 'requested'
                  check (status in ('requested', 'served', 'refused', 'removed')),
  requested_at    timestamptz not null default now(),
  requested_by    uuid references public.members(id),
  served_by       uuid references public.members(id),
  served_at       timestamptz,
  removed_by      uuid references public.members(id),
  removed_at      timestamptz,
  removed_reason  text
);
create index if not exists tab_items_tab_idx on public.tab_items (tab_id);
create index if not exists tab_items_club_idx on public.tab_items (club_id);

create table if not exists public.payments (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs(id) on delete cascade,
  tab_id       uuid not null references public.tabs(id),
  night_id     uuid not null references public.nights(id),
  method       text not null check (method in ('cash', 'mobile_money')),
  amount       int  not null check (amount > 0),
  received_by  uuid references public.members(id),
  created_at   timestamptz not null default now()
);
create index if not exists payments_tab_idx on public.payments (tab_id);
create index if not exists payments_club_idx on public.payments (club_id);

-- ---------------------------------------------------------------------
-- Caisse et depenses
-- ---------------------------------------------------------------------
create table if not exists public.cash_movements (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  night_id    uuid not null references public.nights(id),
  type        text not null check (type in ('in', 'out')),
  amount      int  not null check (amount > 0),
  reason      text not null,
  member_id   uuid references public.members(id),
  created_at  timestamptz not null default now()
);

create table if not exists public.expenses (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs(id) on delete cascade,
  night_id     uuid references public.nights(id),
  label        text not null,
  category     text,
  amount       int  not null check (amount > 0),
  method       text not null default 'cash' check (method in ('cash', 'mobile_money')),
  from_till    boolean not null default true,   -- paye avec l'argent de la caisse
  supplier_id  uuid references public.suppliers(id),
  member_id    uuid references public.members(id),
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Stock
-- ---------------------------------------------------------------------
create table if not exists public.inventories (
  id            uuid primary key default gen_random_uuid(),
  club_id       uuid not null references public.clubs(id) on delete cascade,
  nb_products   int not null default 0,
  nb_ecarts     int not null default 0,
  ecart_valeur  int not null default 0,
  note          text,
  member_id     uuid references public.members(id),
  created_at    timestamptz not null default now()
);

create table if not exists public.stock_entries (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs(id) on delete cascade,
  product_id   uuid not null references public.products(id),
  quantity     int  not null check (quantity > 0),
  cost_price   int  not null default 0 check (cost_price >= 0),
  supplier_id  uuid references public.suppliers(id),
  note         text,
  member_id    uuid references public.members(id),
  created_at   timestamptz not null default now()
);

create table if not exists public.stock_movements (
  id            uuid primary key default gen_random_uuid(),
  club_id       uuid not null references public.clubs(id) on delete cascade,
  product_id    uuid not null references public.products(id),
  type          text not null check (type in ('purchase', 'served', 'return', 'loss', 'adjustment', 'inventory')),
  quantity      int  not null,    -- positif = entree, negatif = sortie
  tab_item_id   uuid references public.tab_items(id),
  entry_id      uuid references public.stock_entries(id),
  inventory_id  uuid references public.inventories(id),
  reason        text,
  member_id     uuid references public.members(id),
  created_at    timestamptz not null default now()
);
create index if not exists stock_movements_product_idx on public.stock_movements (product_id);
create index if not exists stock_movements_club_idx on public.stock_movements (club_id);

-- Stock actuel par boisson (reste limite au club par les droits : security_invoker)
create or replace view public.product_stock
with (security_invoker = true) as
select p.id as product_id,
       p.club_id as club_id,
       coalesce(sum(m.quantity), 0)::int as quantity
from public.products p
left join public.stock_movements m on m.product_id = p.id
where p.track_stock
group by p.id, p.club_id;

-- ---------------------------------------------------------------------
-- Mise a jour automatique de updated_at
-- ---------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists products_touch on public.products;
create trigger products_touch before update on public.products
  for each row execute function public.touch_updated_at();

drop trigger if exists settings_touch on public.settings;
create trigger settings_touch before update on public.settings
  for each row execute function public.touch_updated_at();

-- ===== 02_droits.sql =====
-- =====================================================================
-- BARIO · Script 02 · Qui peut voir et faire quoi
-- Isolation multi-clients + roles.
--   - Chaque personne appartient a UN club : elle ne voit que ce club.
--   - Patron : tout dans son club. Gerant : tout sauf l'equipe.
--     Serveuse : seulement ses propres tables.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Fonctions de droits (toutes limitees au club de la personne connectee)
-- ---------------------------------------------------------------------

-- Le club de la personne connectee (NULL si elle n'est membre d'aucun club).
create or replace function public.my_club()
returns uuid language sql stable security definer set search_path = public as $$
  select club_id from public.members where user_id = auth.uid() and active limit 1
$$;

create or replace function public.my_member_id()
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.members where user_id = auth.uid() and active limit 1
$$;

create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.members where user_id = auth.uid() and active limit 1
$$;

create or replace function public.is_member()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.members where user_id = auth.uid() and active)
$$;

create or replace function public.is_patron()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() = 'patron', false)
$$;

-- patron ou gerant
create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() in ('patron', 'gerant'), false)
$$;

create or replace function public.owns_tab(p_tab_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.tabs t
                 where t.id = p_tab_id and t.waitress_id = public.my_member_id())
$$;

-- ---------------------------------------------------------------------
-- Personne d'autre que les membres connectes
-- ---------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;

-- ---------------------------------------------------------------------
-- Securite par ligne sur toutes les tables
-- ---------------------------------------------------------------------
alter table public.clubs           enable row level security;
alter table public.settings        enable row level security;
alter table public.members         enable row level security;
alter table public.club_tables     enable row level security;
alter table public.categories      enable row level security;
alter table public.products        enable row level security;
alter table public.suppliers       enable row level security;
alter table public.nights          enable row level security;
alter table public.tabs            enable row level security;
alter table public.tab_items       enable row level security;
alter table public.payments        enable row level security;
alter table public.cash_movements  enable row level security;
alter table public.expenses        enable row level security;
alter table public.inventories     enable row level security;
alter table public.stock_entries   enable row level security;
alter table public.stock_movements enable row level security;

-- Club : chaque membre lit son propre club (creation/modif via les fonctions d'admin)
drop policy if exists clubs_read on public.clubs;
create policy clubs_read on public.clubs for select using (id = public.my_club());

-- Reglages : les membres du club lisent, patron et gerant modifient
drop policy if exists settings_read on public.settings;
create policy settings_read on public.settings for select
  using (club_id = public.my_club());
drop policy if exists settings_write on public.settings;
create policy settings_write on public.settings for update
  using (club_id = public.my_club() and public.is_staff())
  with check (club_id = public.my_club() and public.is_staff());

-- Equipe : patron et gerant voient toute l'equipe du club, la serveuse se voit elle-meme.
-- Creer ou modifier un compte passe par les fonctions du script 04.
drop policy if exists members_read on public.members;
create policy members_read on public.members for select
  using (club_id = public.my_club() and (public.is_staff() or user_id = auth.uid()));

-- Tables du club, categories, boissons : les membres lisent, patron et gerant modifient
drop policy if exists club_tables_read on public.club_tables;
create policy club_tables_read on public.club_tables for select
  using (club_id = public.my_club());
drop policy if exists club_tables_write on public.club_tables;
create policy club_tables_write on public.club_tables for all
  using (club_id = public.my_club() and public.is_staff())
  with check (club_id = public.my_club() and public.is_staff());

drop policy if exists categories_read on public.categories;
create policy categories_read on public.categories for select
  using (club_id = public.my_club());
drop policy if exists categories_write on public.categories;
create policy categories_write on public.categories for all
  using (club_id = public.my_club() and public.is_staff())
  with check (club_id = public.my_club() and public.is_staff());

drop policy if exists products_read on public.products;
create policy products_read on public.products for select
  using (club_id = public.my_club());
drop policy if exists products_write on public.products;
create policy products_write on public.products for all
  using (club_id = public.my_club() and public.is_staff())
  with check (club_id = public.my_club() and public.is_staff());

-- Fournisseurs : patron et gerant
drop policy if exists suppliers_all on public.suppliers;
create policy suppliers_all on public.suppliers for all
  using (club_id = public.my_club() and public.is_staff())
  with check (club_id = public.my_club() and public.is_staff());

-- Soirees : les membres du club lisent (la serveuse doit savoir si la soiree est ouverte)
drop policy if exists nights_read on public.nights;
create policy nights_read on public.nights for select
  using (club_id = public.my_club());

-- Notes : patron et gerant voient tout le club, la serveuse voit seulement les siennes
drop policy if exists tabs_read on public.tabs;
create policy tabs_read on public.tabs for select
  using (club_id = public.my_club() and (public.is_staff() or waitress_id = public.my_member_id()));

drop policy if exists tab_items_read on public.tab_items;
create policy tab_items_read on public.tab_items for select
  using (club_id = public.my_club() and (public.is_staff() or public.owns_tab(tab_id)));

drop policy if exists payments_read on public.payments;
create policy payments_read on public.payments for select
  using (club_id = public.my_club() and (public.is_staff() or public.owns_tab(tab_id)));

-- Caisse, depenses, stock : patron et gerant seulement (lecture ;
-- les ecritures passent par les fonctions du script 03)
drop policy if exists cash_movements_read on public.cash_movements;
create policy cash_movements_read on public.cash_movements for select
  using (club_id = public.my_club() and public.is_staff());

drop policy if exists expenses_read on public.expenses;
create policy expenses_read on public.expenses for select
  using (club_id = public.my_club() and public.is_staff());

drop policy if exists inventories_read on public.inventories;
create policy inventories_read on public.inventories for select
  using (club_id = public.my_club() and public.is_staff());

drop policy if exists stock_entries_read on public.stock_entries;
create policy stock_entries_read on public.stock_entries for select
  using (club_id = public.my_club() and public.is_staff());

drop policy if exists stock_movements_read on public.stock_movements;
create policy stock_movements_read on public.stock_movements for select
  using (club_id = public.my_club() and public.is_staff());

-- ---------------------------------------------------------------------
-- Prix d'achat et couts : jamais lisibles directement depuis l'application.
-- Les rapports du patron et du gerant passent par des fonctions.
-- ---------------------------------------------------------------------
revoke select on public.products from authenticated;
grant select (id, club_id, category_id, name, sale_price, track_stock, min_stock, active,
              sort_order, created_at, updated_at)
  on public.products to authenticated;

revoke select on public.tab_items from authenticated;
grant select (id, club_id, tab_id, product_id, product_name, quantity, unit_price, status,
              requested_at, requested_by, served_by, served_at, removed_by,
              removed_at, removed_reason)
  on public.tab_items to authenticated;

-- Les ecritures sur les notes, la caisse et le stock passent par les fonctions
revoke insert, update, delete on public.nights, public.tabs, public.tab_items,
  public.payments, public.cash_movements, public.expenses, public.inventories,
  public.stock_entries, public.stock_movements, public.members, public.clubs
  from authenticated;

-- ===== 03_fonctions.sql =====
-- =====================================================================
-- BARIO · Script 03 · Les fonctions du serveur
-- Soiree, notes, bar, encaissement, caisse, stock, rapports.
-- Chaque fonction verifie le role ET le club de la personne connectee :
-- comme elles s'executent en "security definer" (elles contournent la
-- securite par ligne), elles filtrent elles-memes sur club_id = my_club(),
-- pour qu'un club ne puisse jamais toucher les donnees d'un autre.
-- Les identifiants (p_id) peuvent etre fournis par l'appareil : renvoyer
-- deux fois la meme action (hors ligne) ne la fait qu'une fois.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Outils internes
-- ---------------------------------------------------------------------
create or replace function public._require_member()
returns uuid language plpgsql stable security definer set search_path = public as $$
declare v uuid := public.my_member_id();
begin
  if v is null then raise exception 'Compte non autorise'; end if;
  return v;
end $$;

create or replace function public._require_staff()
returns uuid language plpgsql stable security definer set search_path = public as $$
declare v uuid := public._require_member();
begin
  if not public.is_staff() then raise exception 'Reserve au patron et au gerant'; end if;
  return v;
end $$;

create or replace function public.current_night_id()
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.nights where status = 'open' and club_id = public.my_club() limit 1
$$;

create or replace function public._recalc_tab(p_tab_id uuid)
returns int language plpgsql security definer set search_path = public as $$
declare v_total int;
begin
  select coalesce(sum(quantity * unit_price), 0) into v_total
  from public.tab_items where tab_id = p_tab_id and status = 'served';
  update public.tabs set total = v_total where id = p_tab_id;
  return v_total;
end $$;

-- Charge une note de MON club et verifie que l'appelant peut y toucher
create or replace function public._load_tab(p_tab_id uuid)
returns public.tabs language plpgsql security definer set search_path = public as $$
declare v_tab public.tabs; v_me uuid := public._require_member();
begin
  select * into v_tab from public.tabs
   where id = p_tab_id and club_id = public.my_club() for update;
  if not found then raise exception 'Note introuvable'; end if;
  if not public.is_staff() and v_tab.waitress_id <> v_me then
    raise exception 'Cette note appartient a une autre serveuse';
  end if;
  return v_tab;
end $$;

-- ---------------------------------------------------------------------
-- Soiree
-- ---------------------------------------------------------------------
create or replace function public.open_night(p_opening_float int default 0, p_id uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_me uuid := public._require_staff(); v_club uuid := public.my_club();
        v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  if exists (select 1 from public.nights where id = v_id and club_id = v_club) then return v_id; end if;
  if public.current_night_id() is not null then
    raise exception 'Une soiree est deja ouverte';
  end if;
  insert into public.nights (id, club_id, opened_by, opening_float)
  values (v_id, v_club, v_me, greatest(coalesce(p_opening_float, 0), 0));
  return v_id;
end $$;

create or replace function public.close_night(p_counted_cash int, p_counted_momo int default 0, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public._require_staff();
  v_club uuid := public.my_club();
  v_night public.nights;
  v_cash_pay int; v_momo_pay int; v_in int; v_out int;
  v_exp_cash int; v_exp_momo int;
begin
  select * into v_night from public.nights
   where status = 'open' and club_id = v_club for update;
  if not found then raise exception 'Aucune soiree ouverte'; end if;

  if exists (select 1 from public.tabs where night_id = v_night.id and status in ('open', 'to_pay')) then
    raise exception 'Des notes sont encore ouvertes : encaissez-les ou annulez-les avant la cloture';
  end if;

  select coalesce(sum(p.amount) filter (where p.method = 'cash'), 0),
         coalesce(sum(p.amount) filter (where p.method = 'mobile_money'), 0)
    into v_cash_pay, v_momo_pay
  from public.payments p join public.tabs t on t.id = p.tab_id
  where p.night_id = v_night.id and t.status = 'paid';

  select coalesce(sum(amount) filter (where type = 'in'), 0),
         coalesce(sum(amount) filter (where type = 'out'), 0)
    into v_in, v_out
  from public.cash_movements where night_id = v_night.id;

  select coalesce(sum(amount) filter (where method = 'cash'), 0),
         coalesce(sum(amount) filter (where method = 'mobile_money'), 0)
    into v_exp_cash, v_exp_momo
  from public.expenses where night_id = v_night.id and from_till;

  update public.nights set
    status          = 'closed',
    closed_by       = v_me,
    closed_at       = now(),
    expected_cash   = opening_float + v_cash_pay + v_in - v_out - v_exp_cash,
    expected_momo   = v_momo_pay - v_exp_momo,
    counted_cash    = coalesce(p_counted_cash, 0),
    counted_momo    = coalesce(p_counted_momo, 0),
    difference_cash = coalesce(p_counted_cash, 0) - (opening_float + v_cash_pay + v_in - v_out - v_exp_cash),
    difference_momo = coalesce(p_counted_momo, 0) - (v_momo_pay - v_exp_momo),
    note            = p_note
  where id = v_night.id
  returning * into v_night;

  return jsonb_build_object(
    'night_id', v_night.id,
    'expected_cash', v_night.expected_cash, 'counted_cash', v_night.counted_cash,
    'difference_cash', v_night.difference_cash,
    'expected_momo', v_night.expected_momo, 'counted_momo', v_night.counted_momo,
    'difference_momo', v_night.difference_momo);
end $$;

-- ---------------------------------------------------------------------
-- Tables du club
-- La serveuse peut creer une table provisoire ; patron et gerant
-- peuvent aussi creer des tables fixes.
-- ---------------------------------------------------------------------
create or replace function public.create_table(p_name text, p_zone text default 'salle',
                                               p_fixed boolean default false, p_id uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_me uuid := public._require_member(); v_club uuid := public.my_club();
        v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  if exists (select 1 from public.club_tables where id = v_id and club_id = v_club) then return v_id; end if;
  if coalesce(trim(p_name), '') = '' then raise exception 'Donnez un nom a la table'; end if;
  insert into public.club_tables (id, club_id, name, zone, is_fixed, created_by, sort_order)
  values (v_id, v_club, trim(p_name), coalesce(p_zone, 'salle'),
          coalesce(p_fixed, false) and public.is_staff(), v_me,
          coalesce((select max(sort_order) + 1 from public.club_tables where club_id = v_club), 0));
  return v_id;
exception when unique_violation then
  raise exception 'Une table porte deja ce nom';
end $$;

-- ---------------------------------------------------------------------
-- Notes (serveuse)
-- ---------------------------------------------------------------------
create or replace function public.open_tab(p_table_id uuid, p_id uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_me uuid := public._require_member(); v_club uuid := public.my_club();
        v_id uuid := coalesce(p_id, gen_random_uuid()); v_night uuid := public.current_night_id();
begin
  if exists (select 1 from public.tabs where id = v_id and club_id = v_club) then return v_id; end if;
  if v_night is null then raise exception 'La soiree n''est pas encore ouverte'; end if;
  if not exists (select 1 from public.club_tables where id = p_table_id and club_id = v_club and active) then
    raise exception 'Table introuvable';
  end if;
  insert into public.tabs (id, club_id, night_id, table_id, waitress_id)
  values (v_id, v_club, v_night, p_table_id, v_me);
  return v_id;
exception when unique_violation then
  raise exception 'Cette table a deja une note en cours';
end $$;

-- p_items = [{"id": "<uuid facultatif>", "product_id": "<uuid>", "quantity": 2}, ...]
create or replace function public.add_items(p_tab_id uuid, p_items jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_tab public.tabs := public._load_tab(p_tab_id);
  v_club uuid := public.my_club();
  v_me uuid := public.my_member_id();
  v_item jsonb; v_prod public.products; v_item_id uuid; v_qty int; v_count int := 0;
begin
  if v_tab.status <> 'open' then
    raise exception 'Cette note n''est plus ouverte';
  end if;
  for v_item in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    v_item_id := coalesce((v_item->>'id')::uuid, gen_random_uuid());
    continue when exists (select 1 from public.tab_items where id = v_item_id);
    v_qty := (v_item->>'quantity')::int;
    if v_qty is null or v_qty <= 0 then raise exception 'Quantite invalide'; end if;
    select * into v_prod from public.products
     where id = (v_item->>'product_id')::uuid and club_id = v_club and active;
    if not found then raise exception 'Boisson introuvable ou retiree du menu'; end if;
    insert into public.tab_items (id, club_id, tab_id, product_id, product_name, quantity,
                                  unit_price, cost_price, requested_by)
    values (v_item_id, v_club, p_tab_id, v_prod.id, v_prod.name, v_qty,
            v_prod.sale_price, v_prod.purchase_price, v_me);
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

-- La serveuse annule une boisson pas encore servie
create or replace function public.cancel_request(p_item_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_item public.tab_items; v_tab public.tabs;
begin
  select * into v_item from public.tab_items
   where id = p_item_id and club_id = public.my_club() for update;
  if not found then raise exception 'Boisson introuvable'; end if;
  v_tab := public._load_tab(v_item.tab_id);
  if v_item.status <> 'requested' then
    raise exception 'Cette boisson a deja ete traitee par le bar';
  end if;
  update public.tab_items
     set status = 'removed', removed_by = public.my_member_id(), removed_at = now(),
         removed_reason = 'Annulee avant service'
   where id = p_item_id;
end $$;

-- Demander l'encaissement : la note part au gerant
create or replace function public.request_payment(p_tab_id uuid)
returns int language plpgsql security definer set search_path = public as $$
declare v_tab public.tabs := public._load_tab(p_tab_id); v_total int;
begin
  if v_tab.status = 'to_pay' then return v_tab.total; end if;
  if v_tab.status <> 'open' then raise exception 'Cette note n''est plus ouverte'; end if;
  if exists (select 1 from public.tab_items where tab_id = p_tab_id and status = 'requested') then
    raise exception 'Des boissons attendent encore le bar';
  end if;
  v_total := public._recalc_tab(p_tab_id);
  if v_total = 0 then raise exception 'La note est vide'; end if;
  update public.tabs set status = 'to_pay', requested_at = now() where id = p_tab_id;
  return v_total;
end $$;

-- Le client recommande apres avoir demande la facture
create or replace function public.reopen_tab(p_tab_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_tab public.tabs := public._load_tab(p_tab_id);
begin
  if v_tab.status = 'open' then return; end if;
  if v_tab.status <> 'to_pay' then raise exception 'Cette note ne peut plus etre rouverte'; end if;
  if v_tab.paid_amount > 0 then raise exception 'Un paiement a deja ete recu sur cette note'; end if;
  update public.tabs set status = 'open', requested_at = null where id = p_tab_id;
end $$;

-- ---------------------------------------------------------------------
-- Bar (gerant)
-- ---------------------------------------------------------------------
create or replace function public.serve_items(p_item_ids uuid[])
returns int language plpgsql security definer set search_path = public as $$
declare v_me uuid := public._require_staff(); v_club uuid := public.my_club();
        v_item record; v_count int := 0;
begin
  for v_item in
    select i.*, p.track_stock, t.status as tab_status
    from public.tab_items i
    join public.products p on p.id = i.product_id
    join public.tabs t on t.id = i.tab_id
    where i.id = any(p_item_ids) and i.status = 'requested' and i.club_id = v_club
    for update of i
  loop
    if v_item.tab_status <> 'open' then
      raise exception 'La note de cette boisson n''est plus ouverte';
    end if;
    update public.tab_items set status = 'served', served_by = v_me, served_at = now()
     where id = v_item.id;
    if v_item.track_stock then
      insert into public.stock_movements (club_id, product_id, type, quantity, tab_item_id, member_id)
      values (v_club, v_item.product_id, 'served', -v_item.quantity, v_item.id, v_me);
    end if;
    perform public._recalc_tab(v_item.tab_id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

create or replace function public.refuse_items(p_item_ids uuid[], p_reason text default 'Rupture de stock')
returns int language plpgsql security definer set search_path = public as $$
declare v_me uuid := public._require_staff(); v_count int;
begin
  update public.tab_items
     set status = 'refused', removed_by = v_me, removed_at = now(),
         removed_reason = coalesce(nullif(trim(p_reason), ''), 'Rupture de stock')
   where id = any(p_item_ids) and status = 'requested' and club_id = public.my_club();
  get diagnostics v_count = row_count;
  return v_count;
end $$;

-- Retirer une boisson deja servie (casse, erreur). p_restock = la bouteille revient en stock.
create or replace function public.remove_item(p_item_id uuid, p_reason text, p_restock boolean default false)
returns int language plpgsql security definer set search_path = public as $$
declare v_me uuid := public._require_staff(); v_club uuid := public.my_club();
        v_item record; v_total int;
begin
  if coalesce(trim(p_reason), '') = '' then raise exception 'Indiquez la raison'; end if;
  select i.*, p.track_stock, t.status as tab_status, t.paid_amount
    into v_item
  from public.tab_items i
  join public.products p on p.id = i.product_id
  join public.tabs t on t.id = i.tab_id
  where i.id = p_item_id and i.club_id = v_club
  for update of i;
  if not found then raise exception 'Boisson introuvable'; end if;
  if v_item.status <> 'served' then raise exception 'Seule une boisson servie peut etre retiree'; end if;
  if v_item.tab_status not in ('open', 'to_pay') then raise exception 'Cette note est deja cloturee'; end if;

  update public.tab_items
     set status = 'removed', removed_by = v_me, removed_at = now(), removed_reason = trim(p_reason)
   where id = p_item_id;

  if p_restock and v_item.track_stock then
    insert into public.stock_movements (club_id, product_id, type, quantity, tab_item_id, reason, member_id)
    values (v_club, v_item.product_id, 'return', v_item.quantity, v_item.id, trim(p_reason), v_me);
  end if;

  v_total := public._recalc_tab(v_item.tab_id);
  if v_total < v_item.paid_amount then
    raise exception 'Le total deviendrait inferieur a ce qui a deja ete paye';
  end if;
  return v_total;
end $$;

-- ---------------------------------------------------------------------
-- Encaissement (gerant) · paiement en une ou plusieurs fois
-- ---------------------------------------------------------------------
create or replace function public.record_payment(p_tab_id uuid, p_method text, p_amount int, p_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me uuid := public._require_staff(); v_club uuid := public.my_club();
        v_tab public.tabs; v_id uuid := coalesce(p_id, gen_random_uuid()); v_remaining int;
begin
  select * into v_tab from public.tabs where id = p_tab_id and club_id = v_club for update;
  if not found then raise exception 'Note introuvable'; end if;

  if not exists (select 1 from public.payments where id = v_id) then
    if v_tab.status <> 'to_pay' then
      raise exception 'Cette note n''attend pas d''encaissement';
    end if;
    if p_method not in ('cash', 'mobile_money') then raise exception 'Mode de paiement inconnu'; end if;
    v_remaining := v_tab.total - v_tab.paid_amount;
    if p_amount is null or p_amount <= 0 then raise exception 'Montant invalide'; end if;
    if p_amount > v_remaining then
      raise exception 'Montant trop eleve : il reste % FCFA a payer', v_remaining;
    end if;

    insert into public.payments (id, club_id, tab_id, night_id, method, amount, received_by)
    values (v_id, v_club, p_tab_id, v_tab.night_id, p_method, p_amount, v_me);

    update public.tabs set paid_amount = paid_amount + p_amount where id = p_tab_id
    returning * into v_tab;

    if v_tab.paid_amount >= v_tab.total then
      -- Numero de ticket propre a ce club (1, 2, 3, ... par club)
      update public.tabs set status = 'paid', paid_at = now(), cashier_id = v_me,
                             ticket_number = coalesce(
                               (select max(ticket_number) from public.tabs where club_id = v_club), 0) + 1
       where id = p_tab_id
      returning * into v_tab;
    end if;
  end if;

  return jsonb_build_object('status', v_tab.status, 'total', v_tab.total,
                            'paid', v_tab.paid_amount, 'remaining', v_tab.total - v_tab.paid_amount,
                            'ticket_number', v_tab.ticket_number);
end $$;

-- Annuler une note. Une note payee (ou partiellement payee) : patron seulement.
create or replace function public.cancel_tab(p_tab_id uuid, p_reason text, p_restock boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare v_me uuid := public._require_staff(); v_club uuid := public.my_club();
        v_tab public.tabs; v_item record;
begin
  if coalesce(trim(p_reason), '') = '' then raise exception 'Indiquez la raison'; end if;
  select * into v_tab from public.tabs where id = p_tab_id and club_id = v_club for update;
  if not found then raise exception 'Note introuvable'; end if;
  if v_tab.status = 'cancelled' then return; end if;
  if (v_tab.status = 'paid' or v_tab.paid_amount > 0) and not public.is_patron() then
    raise exception 'Seul le patron peut annuler une note deja payee';
  end if;

  if p_restock then
    for v_item in
      select i.* from public.tab_items i join public.products p on p.id = i.product_id
      where i.tab_id = p_tab_id and i.status = 'served' and p.track_stock
    loop
      insert into public.stock_movements (club_id, product_id, type, quantity, tab_item_id, reason, member_id)
      values (v_club, v_item.product_id, 'return', v_item.quantity, v_item.id, 'Note annulee', v_me);
    end loop;
  end if;

  update public.tab_items set status = 'removed', removed_by = v_me, removed_at = now(),
         removed_reason = 'Note annulee'
   where tab_id = p_tab_id and status = 'requested';

  update public.tabs set status = 'cancelled', cancelled_by = v_me, cancel_reason = trim(p_reason)
   where id = p_tab_id;
end $$;

-- ---------------------------------------------------------------------
-- Caisse et depenses (gerant)
-- ---------------------------------------------------------------------
create or replace function public.add_cash_movement(p_type text, p_amount int, p_reason text, p_id uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_me uuid := public._require_staff(); v_club uuid := public.my_club();
        v_id uuid := coalesce(p_id, gen_random_uuid()); v_night uuid := public.current_night_id();
begin
  if exists (select 1 from public.cash_movements where id = v_id and club_id = v_club) then return v_id; end if;
  if v_night is null then raise exception 'Aucune soiree ouverte'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'Indiquez la raison'; end if;
  insert into public.cash_movements (id, club_id, night_id, type, amount, reason, member_id)
  values (v_id, v_club, v_night, p_type, p_amount, trim(p_reason), v_me);
  return v_id;
end $$;

create or replace function public.record_expense(p_label text, p_amount int, p_method text default 'cash',
                                                 p_from_till boolean default true, p_category text default null,
                                                 p_supplier_id uuid default null, p_id uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_me uuid := public._require_staff(); v_club uuid := public.my_club();
        v_id uuid := coalesce(p_id, gen_random_uuid()); v_night uuid := public.current_night_id();
begin
  if exists (select 1 from public.expenses where id = v_id and club_id = v_club) then return v_id; end if;
  if p_from_till and v_night is null then
    raise exception 'Aucune soiree ouverte pour payer depuis la caisse';
  end if;
  insert into public.expenses (id, club_id, night_id, label, category, amount, method, from_till, supplier_id, member_id)
  values (v_id, v_club, v_night, p_label, p_category, p_amount, coalesce(p_method, 'cash'),
          coalesce(p_from_till, true), p_supplier_id, v_me);
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- Stock (gerant)
-- ---------------------------------------------------------------------
create or replace function public.receive_stock(p_product_id uuid, p_quantity int, p_cost_price int default 0,
                                                p_supplier_id uuid default null, p_note text default null,
                                                p_id uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_me uuid := public._require_staff(); v_club uuid := public.my_club();
        v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  if exists (select 1 from public.stock_entries where id = v_id and club_id = v_club) then return v_id; end if;
  if not exists (select 1 from public.products where id = p_product_id and club_id = v_club and track_stock) then
    raise exception 'Boisson introuvable ou sans suivi de stock';
  end if;
  insert into public.stock_entries (id, club_id, product_id, quantity, cost_price, supplier_id, note, member_id)
  values (v_id, v_club, p_product_id, p_quantity, coalesce(p_cost_price, 0), p_supplier_id, p_note, v_me);
  insert into public.stock_movements (club_id, product_id, type, quantity, entry_id, member_id)
  values (v_club, p_product_id, 'purchase', p_quantity, v_id, v_me);
  if coalesce(p_cost_price, 0) > 0 then
    update public.products set purchase_price = p_cost_price where id = p_product_id and club_id = v_club;
  end if;
  return v_id;
end $$;

-- p_type : 'loss' (casse, vol : quantite negative) ou 'adjustment' (correction)
create or replace function public.adjust_stock(p_product_id uuid, p_quantity int, p_type text, p_reason text,
                                               p_id uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_me uuid := public._require_staff(); v_club uuid := public.my_club();
        v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  if exists (select 1 from public.stock_movements where id = v_id and club_id = v_club) then return v_id; end if;
  if p_type not in ('loss', 'adjustment') then raise exception 'Type inconnu'; end if;
  if coalesce(p_quantity, 0) = 0 then raise exception 'Quantite invalide'; end if;
  if p_type = 'loss' and p_quantity > 0 then raise exception 'Une perte doit etre negative'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'Indiquez la raison'; end if;
  if not exists (select 1 from public.products where id = p_product_id and club_id = v_club) then
    raise exception 'Boisson introuvable';
  end if;
  insert into public.stock_movements (id, club_id, product_id, type, quantity, reason, member_id)
  values (v_id, v_club, p_product_id, p_type, p_quantity, trim(p_reason), v_me);
  return v_id;
end $$;

-- p_lines = [{"product_id": "<uuid>", "counted": 12}, ...]
create or replace function public.record_inventory(p_lines jsonb, p_note text default null, p_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public._require_staff(); v_club uuid := public.my_club();
  v_id uuid := coalesce(p_id, gen_random_uuid());
  v_line jsonb; v_pid uuid; v_counted int; v_current int; v_diff int; v_cost int;
  v_nb int := 0; v_ecarts int := 0; v_valeur int := 0;
begin
  if exists (select 1 from public.inventories where id = v_id and club_id = v_club) then
    return (select to_jsonb(i) from public.inventories i where id = v_id);
  end if;
  insert into public.inventories (id, club_id, note, member_id) values (v_id, v_club, p_note, v_me);
  for v_line in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_pid := (v_line->>'product_id')::uuid;
    v_counted := (v_line->>'counted')::int;
    continue when v_pid is null or v_counted is null;
    if not exists (select 1 from public.products where id = v_pid and club_id = v_club) then continue; end if;
    select coalesce(sum(quantity), 0) into v_current from public.stock_movements
     where product_id = v_pid and club_id = v_club;
    select purchase_price into v_cost from public.products where id = v_pid and club_id = v_club;
    v_diff := v_counted - v_current;
    v_nb := v_nb + 1;
    if v_diff <> 0 then
      v_ecarts := v_ecarts + 1;
      v_valeur := v_valeur + v_diff * coalesce(v_cost, 0);
      insert into public.stock_movements (club_id, product_id, type, quantity, inventory_id, reason, member_id)
      values (v_club, v_pid, 'inventory', v_diff, v_id, 'Inventaire', v_me);
    end if;
  end loop;
  update public.inventories set nb_products = v_nb, nb_ecarts = v_ecarts, ecart_valeur = v_valeur
   where id = v_id;
  return jsonb_build_object('id', v_id, 'nb_products', v_nb, 'nb_ecarts', v_ecarts, 'ecart_valeur', v_valeur);
end $$;

-- ---------------------------------------------------------------------
-- Lectures reservees au patron et au gerant
-- ---------------------------------------------------------------------
-- Stock avec prix d'achat
create or replace function public.stock_overview()
returns table (product_id uuid, category text, name text, quantity int, min_stock int,
               purchase_price int, sale_price int, low boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_club uuid := public.my_club();
begin
  perform public._require_staff();
  return query
  select p.id, c.name, p.name, coalesce(s.quantity, 0), p.min_stock,
         p.purchase_price, p.sale_price, coalesce(s.quantity, 0) <= p.min_stock
  from public.products p
  left join public.categories c on c.id = p.category_id
  left join public.product_stock s on s.product_id = p.id
  where p.club_id = v_club and p.active and p.track_stock
  order by c.sort_order, p.sort_order, p.name;
end $$;

-- Rapport d'une soiree (la soiree en cours si p_night_id est vide)
create or replace function public.night_report(p_night_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_night public.nights; v_club uuid := public.my_club(); v_id uuid;
begin
  perform public._require_staff();
  v_id := coalesce(p_night_id, public.current_night_id(),
                   (select id from public.nights where club_id = v_club order by opened_at desc limit 1));
  select * into v_night from public.nights where id = v_id and club_id = v_club;
  if not found then raise exception 'Soiree introuvable'; end if;

  return jsonb_build_object(
    'night', to_jsonb(v_night),
    'revenue', (select coalesce(sum(total), 0) from public.tabs where night_id = v_id and status = 'paid'),
    'tabs_paid', (select count(*) from public.tabs where night_id = v_id and status = 'paid'),
    'tabs_open', (select count(*) from public.tabs where night_id = v_id and status in ('open', 'to_pay')),
    'tabs_cancelled', (select count(*) from public.tabs where night_id = v_id and status = 'cancelled'),
    'cost', (select coalesce(sum(i.quantity * i.cost_price), 0)
             from public.tab_items i join public.tabs t on t.id = i.tab_id
             where t.night_id = v_id and t.status = 'paid' and i.status = 'served'),
    'payments', (select jsonb_build_object(
                   'cash', coalesce(sum(p.amount) filter (where p.method = 'cash'), 0),
                   'mobile_money', coalesce(sum(p.amount) filter (where p.method = 'mobile_money'), 0))
                 from public.payments p join public.tabs t on t.id = p.tab_id
                 where p.night_id = v_id and t.status = 'paid'),
    'expenses', (select coalesce(sum(amount), 0) from public.expenses where night_id = v_id),
    'by_waitress', (select coalesce(jsonb_agg(w order by w.revenue desc), '[]'::jsonb) from (
        select m.id, m.display_name,
               count(distinct t.id) filter (where t.status = 'paid') as tabs,
               coalesce(sum(i.quantity) filter (where t.status = 'paid' and i.status = 'served'), 0) as items,
               coalesce(sum(i.quantity * i.unit_price) filter (where t.status = 'paid' and i.status = 'served'), 0) as revenue,
               count(distinct t.id) filter (where t.status in ('open', 'to_pay')) as open_tabs,
               coalesce(sum(i.quantity) filter (where i.status = 'removed' and i.served_at is not null), 0) as removed_after_service
        from public.tabs t
        join public.members m on m.id = t.waitress_id
        left join public.tab_items i on i.tab_id = t.id
        where t.night_id = v_id
        group by m.id, m.display_name) w),
    'top_products', (select coalesce(jsonb_agg(x order by x.quantity desc), '[]'::jsonb) from (
        select i.product_name as name, sum(i.quantity) as quantity,
               sum(i.quantity * i.unit_price) as revenue,
               sum(i.quantity * (i.unit_price - i.cost_price)) as margin
        from public.tab_items i join public.tabs t on t.id = i.tab_id
        where t.night_id = v_id and t.status = 'paid' and i.status = 'served'
        group by i.product_name
        order by sum(i.quantity) desc
        limit 15) x)
  );
end $$;

-- ---------------------------------------------------------------------
-- Droits d'execution
-- ---------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon;
grant execute on function
  public.my_club(), public.my_member_id(), public.my_role(),
  public.is_member(), public.is_patron(), public.is_staff(),
  public.owns_tab(uuid), public.current_night_id(),
  public.open_night(int, uuid), public.close_night(int, int, text),
  public.create_table(text, text, boolean, uuid),
  public.open_tab(uuid, uuid), public.add_items(uuid, jsonb), public.cancel_request(uuid),
  public.request_payment(uuid), public.reopen_tab(uuid),
  public.serve_items(uuid[]), public.refuse_items(uuid[], text), public.remove_item(uuid, text, boolean),
  public.record_payment(uuid, text, int, uuid), public.cancel_tab(uuid, text, boolean),
  public.add_cash_movement(text, int, text, uuid),
  public.record_expense(text, int, text, boolean, text, uuid, uuid),
  public.receive_stock(uuid, int, int, uuid, text, uuid),
  public.adjust_stock(uuid, int, text, text, uuid),
  public.record_inventory(jsonb, text, uuid),
  public.stock_overview(), public.night_report(uuid)
to authenticated;

-- ===== 04_comptes.sql =====
-- =====================================================================
-- BARIO · Script 04 · Les comptes de l'equipe
-- Connexion par CODE DU CLUB + identifiant + code PIN a 6 chiffres.
--
-- Comme Bario sert plusieurs clubs, un meme identifiant (ex. "gerant")
-- peut exister dans deux clubs differents. Pour les distinguer, l'adresse
-- interne de Supabase inclut le code du club :
--     identifiant@<code-du-club>.bario.invalid
-- Cette adresse ne recoit jamais d'e-mail.
--
-- L'appareil retient le code du club apres la premiere mise en place ;
-- ensuite, l'equipe tape seulement identifiant + PIN.
-- =====================================================================

-- Code court et lisible pour chaque club (sans 0 O 1 I). Sert d'adresse interne.
alter table public.clubs add column if not exists code text unique;

create or replace function public._club_nouveau_code() returns text
language plpgsql volatile as $$
declare
  alphabet constant text := 'abcdefghjkmnpqrstuvwxyz23456789';
  octets bytea := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
  code text := '';
  i int;
begin
  for i in 1..6 loop
    code := code || substr(alphabet, (get_byte(octets, i) % 30) + 1, 1);
  end loop;
  return code;   -- 6 caracteres, ex. "k7m3qp"
end $$;

-- ---------------------------------------------------------------------
-- Outils de connexion
-- ---------------------------------------------------------------------
create or replace function public._login_email(p_login text, p_code text)
returns text language sql immutable as $$
  select lower(trim(p_login)) || '@' || lower(trim(p_code)) || '.bario.invalid'
$$;

create or replace function public._check_login_pin(p_login text, p_pin text)
returns void language plpgsql immutable as $$
begin
  if lower(trim(coalesce(p_login, ''))) !~ '^[a-z0-9._-]{3,30}$' then
    raise exception 'Identifiant invalide : 3 a 30 caracteres, lettres minuscules, chiffres, point ou tiret';
  end if;
  if coalesce(p_pin, '') !~ '^[0-9]{6}$' then
    raise exception 'Le code PIN doit contenir exactement 6 chiffres';
  end if;
end $$;

-- Cree l'utilisateur Supabase (auth) pour un club donne et renvoie son identifiant
create or replace function public._create_auth_user(p_login text, p_pin text, p_code text)
returns uuid language plpgsql security definer set search_path = public, extensions, auth as $$
declare v_uid uuid := gen_random_uuid(); v_email text := public._login_email(p_login, p_code);
begin
  if exists (select 1 from auth.users where email = v_email) then
    raise exception 'Cet identifiant est deja utilise dans ce club';
  end if;
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                          confirmation_token, email_change, email_change_token_new, recovery_token)
  values ('00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated', v_email,
          extensions.crypt(p_pin, extensions.gen_salt('bf')), now(),
          '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now(),
          '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, identity_data, provider,
                               last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), v_uid, v_uid::text,
          jsonb_build_object('sub', v_uid::text, 'email', v_email, 'email_verified', true),
          'email', now(), now(), now());
  return v_uid;
end $$;

-- ---------------------------------------------------------------------
-- Mise en place de l'appareil : retrouver un club par son code.
-- Appelable sans etre connecte (l'appareil confirme le nom du club avant
-- la premiere connexion). Ne renvoie que le nom.
-- ---------------------------------------------------------------------
create or replace function public.club_by_code(p_code text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_club public.clubs;
begin
  select * into v_club from public.clubs where code = lower(trim(p_code));
  if not found then
    return jsonb_build_object('trouve', false);
  end if;
  return jsonb_build_object('trouve', true, 'code', v_club.code, 'nom', v_club.name);
end $$;

-- ---------------------------------------------------------------------
-- Gestion de l'equipe (patron seulement, dans SON club)
-- ---------------------------------------------------------------------
create or replace function public.create_member(p_login text, p_pin text, p_display_name text,
                                                p_role text default 'serveuse', p_phone text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_club uuid := public.my_club(); v_code text; v_uid uuid; v_id uuid;
begin
  if not public.is_patron() then raise exception 'Seul le patron peut creer un compte'; end if;
  if p_role not in ('patron', 'gerant', 'serveuse') then raise exception 'Role inconnu'; end if;
  if coalesce(trim(p_display_name), '') = '' then raise exception 'Indiquez le nom'; end if;
  perform public._check_login_pin(p_login, p_pin);
  select code into v_code from public.clubs where id = v_club;
  if exists (select 1 from public.members where club_id = v_club and login = lower(trim(p_login))) then
    raise exception 'Cet identifiant est deja utilise dans ce club';
  end if;
  v_uid := public._create_auth_user(p_login, p_pin, v_code);
  insert into public.members (club_id, user_id, login, role, display_name, phone)
  values (v_club, v_uid, lower(trim(p_login)), p_role, trim(p_display_name), p_phone)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.set_member_pin(p_member_id uuid, p_pin text)
returns void language plpgsql security definer set search_path = public, extensions, auth as $$
declare v_uid uuid;
begin
  if not public.is_patron() then raise exception 'Seul le patron peut changer un code PIN'; end if;
  if coalesce(p_pin, '') !~ '^[0-9]{6}$' then raise exception 'Le code PIN doit contenir exactement 6 chiffres'; end if;
  select user_id into v_uid from public.members where id = p_member_id and club_id = public.my_club();
  if v_uid is null then raise exception 'Compte introuvable'; end if;
  update auth.users set encrypted_password = extensions.crypt(p_pin, extensions.gen_salt('bf')),
                        updated_at = now()
   where id = v_uid;
end $$;

create or replace function public.update_member(p_member_id uuid, p_display_name text,
                                                p_role text, p_phone text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_club uuid := public.my_club(); v_old public.members;
begin
  if not public.is_patron() then raise exception 'Seul le patron peut modifier un compte'; end if;
  if p_role not in ('patron', 'gerant', 'serveuse') then raise exception 'Role inconnu'; end if;
  select * into v_old from public.members where id = p_member_id and club_id = v_club for update;
  if not found then raise exception 'Compte introuvable'; end if;
  if v_old.role = 'patron' and p_role <> 'patron'
     and (select count(*) from public.members where club_id = v_club and role = 'patron' and active) <= 1 then
    raise exception 'Il doit toujours rester au moins un patron';
  end if;
  update public.members set display_name = trim(p_display_name), role = p_role, phone = p_phone
   where id = p_member_id;
end $$;

-- Desactiver un compte : la personne ne peut plus rien faire, son historique reste
create or replace function public.set_member_active(p_member_id uuid, p_active boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_club uuid := public.my_club(); v_m public.members;
begin
  if not public.is_patron() then raise exception 'Seul le patron peut activer ou desactiver un compte'; end if;
  select * into v_m from public.members where id = p_member_id and club_id = v_club for update;
  if not found then raise exception 'Compte introuvable'; end if;
  if not p_active and v_m.user_id = auth.uid() then
    raise exception 'Vous ne pouvez pas desactiver votre propre compte';
  end if;
  if not p_active and v_m.role = 'patron'
     and (select count(*) from public.members where club_id = v_club and role = 'patron' and active) <= 1 then
    raise exception 'Il doit toujours rester au moins un patron';
  end if;
  update public.members set active = p_active where id = p_member_id;
end $$;

-- ---------------------------------------------------------------------
-- Changer son propre identifiant et code PIN (chacun, depuis Reglages)
-- ---------------------------------------------------------------------
create or replace function public.change_my_credentials(p_new_login text default null, p_new_pin text default null)
returns text language plpgsql security definer set search_path = public, extensions, auth as $$
declare v_me public.members; v_code text; v_login text; v_email text;
begin
  select * into v_me from public.members where user_id = auth.uid() and active;
  if v_me is null then raise exception 'Compte non autorise'; end if;
  select code into v_code from public.clubs where id = v_me.club_id;

  -- Code PIN
  if p_new_pin is not null and p_new_pin <> '' then
    if p_new_pin !~ '^[0-9]{6}$' then
      raise exception 'Le code PIN doit contenir exactement 6 chiffres';
    end if;
    update auth.users
       set encrypted_password = extensions.crypt(p_new_pin, extensions.gen_salt('bf')), updated_at = now()
     where id = v_me.user_id;
  end if;

  -- Identifiant
  v_login := v_me.login;
  if p_new_login is not null and lower(trim(p_new_login)) <> v_me.login then
    v_login := lower(trim(p_new_login));
    if v_login !~ '^[a-z0-9._-]{3,30}$' then
      raise exception 'Identifiant invalide : 3 a 30 caracteres, lettres minuscules, chiffres, point ou tiret';
    end if;
    if exists (select 1 from public.members where club_id = v_me.club_id and login = v_login and id <> v_me.id) then
      raise exception 'Cet identifiant est deja utilise dans ce club';
    end if;
    v_email := public._login_email(v_login, v_code);
    if exists (select 1 from auth.users where email = v_email and id <> v_me.user_id) then
      raise exception 'Cet identifiant est deja utilise dans ce club';
    end if;
    update auth.users set email = v_email, updated_at = now() where id = v_me.user_id;
    update auth.identities
       set identity_data = jsonb_set(identity_data, '{email}', to_jsonb(v_email)), updated_at = now()
     where user_id = v_me.user_id;
    update public.members set login = v_login where id = v_me.id;
  end if;

  return v_login;
end $$;

-- ---------------------------------------------------------------------
-- Supprimer definitivement un membre (patron). Refuse s'il a deja
-- travaille (on le desactive alors pour garder l'historique).
-- ---------------------------------------------------------------------
create or replace function public.delete_member(p_member_id uuid)
returns void language plpgsql security definer set search_path = public, auth as $$
declare v_club uuid := public.my_club(); v_m public.members; v_uid uuid;
begin
  if not public.is_patron() then raise exception 'Seul le patron peut supprimer un compte'; end if;
  select * into v_m from public.members where id = p_member_id and club_id = v_club;
  if not found then return; end if;
  if v_m.user_id = auth.uid() then raise exception 'Vous ne pouvez pas supprimer votre propre compte'; end if;
  if v_m.role = 'patron'
     and (select count(*) from public.members where club_id = v_club and role = 'patron' and id <> p_member_id) = 0 then
    raise exception 'Il doit toujours rester au moins un patron';
  end if;

  v_uid := v_m.user_id;
  begin
    delete from public.members where id = p_member_id;
  exception when foreign_key_violation then
    raise exception 'Ce membre a deja travaille (notes, paiements, stock...). '
                    'Impossible de le supprimer sans effacer cet historique : desactivez-le plutot.';
  end;

  if v_uid is not null then
    delete from auth.users where id = v_uid;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Droits d'execution
-- ---------------------------------------------------------------------
revoke execute on function public._club_nouveau_code(), public._login_email(text, text),
  public._check_login_pin(text, text), public._create_auth_user(text, text, text)
  from public, anon, authenticated;

-- club_by_code est appelable sans connexion (mise en place de l'appareil)
revoke execute on function public.club_by_code(text) from public;
grant execute on function public.club_by_code(text) to anon, authenticated;

revoke execute on function public.create_member(text, text, text, text, text),
  public.set_member_pin(uuid, text), public.update_member(uuid, text, text, text),
  public.set_member_active(uuid, boolean), public.change_my_credentials(text, text),
  public.delete_member(uuid)
  from public, anon;
grant execute on function public.create_member(text, text, text, text, text),
  public.set_member_pin(uuid, text), public.update_member(uuid, text, text, text),
  public.set_member_active(uuid, boolean), public.change_my_credentials(text, text),
  public.delete_member(uuid)
  to authenticated;

-- ===== 05_tables_occupees.sql =====
-- =====================================================================
-- BARIO · Script 05 · Tables occupees visibles par toutes les serveuses
-- Chaque table du club indique la note en cours (sans montant ni detail).
-- Ainsi une serveuse ne peut plus ouvrir une table deja prise par une
-- collegue du MEME club. Relancable sans danger.
-- =====================================================================

alter table public.club_tables add column if not exists current_tab_id uuid;

create or replace function public._maj_table_occupee()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_table uuid;
begin
  foreach v_table in array array[new.table_id, case when tg_op = 'UPDATE' then old.table_id end] loop
    continue when v_table is null;
    update public.club_tables
       set current_tab_id = (select t.id from public.tabs t
                             where t.table_id = v_table and t.status in ('open', 'to_pay')
                             order by t.opened_at desc limit 1)
     where id = v_table;
  end loop;
  return new;
end $$;

drop trigger if exists tabs_table_occupee on public.tabs;
create trigger tabs_table_occupee
  after insert or update of status, table_id on public.tabs
  for each row execute function public._maj_table_occupee();

-- Remise a niveau des tables deja ouvertes
update public.club_tables ct
   set current_tab_id = (select t.id from public.tabs t
                         where t.table_id = ct.id and t.status in ('open', 'to_pay')
                         order by t.opened_at desc limit 1);

grant select (current_tab_id) on public.club_tables to authenticated;
revoke execute on function public._maj_table_occupee() from public, anon, authenticated;

-- ===== 06_remise_a_zero.sql =====
-- =====================================================================
-- BARIO · Script 06 · Remise a zero (patron seulement)
-- Efface l'activite de SON club : soirees, notes, boissons servies,
-- paiements, depenses, mouvements de caisse, tables provisoires.
-- Option : remettre aussi le stock a zero (entrees, pertes, inventaires).
-- Toujours gardes : le menu, les prix, les tables fixes, l'equipe, les reglages.
-- Les recus repartent naturellement a 1 (le numero est propre au club).
-- Utilisee depuis le logiciel : Reglages > Remettre a zero.
-- =====================================================================

create or replace function public.reset_club(p_confirmation text, p_stock boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_club uuid := public.my_club(); v_notes int; v_soirees int;
begin
  if not public.is_patron() then raise exception 'Seul le patron peut remettre le logiciel a zero'; end if;
  if coalesce(upper(trim(p_confirmation)), '') <> 'EFFACER' then
    raise exception 'Confirmation incorrecte : tapez EFFACER';
  end if;

  select count(*) into v_notes from public.tabs where club_id = v_club;
  select count(*) into v_soirees from public.nights where club_id = v_club;

  if p_stock then
    delete from public.stock_movements where club_id = v_club;
    delete from public.stock_entries where club_id = v_club;
    delete from public.inventories where club_id = v_club;
  else
    -- Le stock reste juste : les sorties deja comptees sont gardees, sans lien vers les notes effacees.
    update public.stock_movements set tab_item_id = null where club_id = v_club and tab_item_id is not null;
  end if;

  delete from public.payments where club_id = v_club;
  delete from public.tab_items where club_id = v_club;
  delete from public.tabs where club_id = v_club;
  delete from public.cash_movements where club_id = v_club;
  delete from public.expenses where club_id = v_club;
  delete from public.nights where club_id = v_club;

  update public.club_tables set current_tab_id = null where club_id = v_club and current_tab_id is not null;
  delete from public.club_tables where club_id = v_club and not is_fixed;

  return jsonb_build_object('notes_effacees', v_notes, 'soirees_effacees', v_soirees, 'stock_remis_a_zero', p_stock);
end $$;

revoke execute on function public.reset_club(text, boolean) from public, anon;
grant execute on function public.reset_club(text, boolean) to authenticated;

-- ===== 08_licences_abonnement.sql =====
-- =====================================================================
-- BARIO · Script 08 · Licences, abonnement et espace admin
-- A coller dans Supabase > SQL Editor > New query, puis « Run ».
--
-- Modele : un client = un club. L'abonnement est porte par le club.
--   - C'est TOI (admin de Bario) qui crees le club et son patron, et
--     fixes la date de fin d'abonnement. Tu donnes au client son CODE DE CLUB.
--   - Tarifs par defaut : 25 000 FCFA / mois. (Installation 200 000 FCFA :
--     geste commercial hors logiciel, note comme tu veux.)
--   - 7 jours avant la fin : avertissement. Apres la fin : 7 jours de grace
--     (le logiciel marche encore, bandeau rouge), puis il se BLOQUE.
--   - Le blocage est verifie aussi cote serveur : meme une appli modifiee
--     ne peut plus rien enregistrer tant que ce n'est pas paye.
--   - Tu peux a tout moment suspendre/reactiver, prolonger, offrir des jours.
-- =====================================================================

-- ---------- Champs d'abonnement sur le club ----------
alter table public.clubs add column if not exists monthly_price integer not null default 25000
  check (monthly_price >= 0);
alter table public.clubs add column if not exists expires_at timestamptz;      -- null = illimite
alter table public.clubs add column if not exists suspended boolean not null default false;  -- blocage manuel

-- Delai de grace avant blocage (7 jours).
create or replace function public.bario_grace() returns interval
language sql immutable as $$ select interval '7 days' $$;

-- ---------- Administrateurs de la plateforme (toi) ----------
create table if not exists public.platform_admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.platform_admins enable row level security;  -- aucune regle : personne ne la lit directement

create or replace function public.is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid())
$$;

create or replace function public._exiger_admin() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Reserve a l''administrateur de Bario';
  end if;
end $$;

-- ---------- Paiements d'abonnement recus ----------
create table if not exists public.subscription_payments (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  amount      integer not null check (amount > 0),
  months      integer not null check (months between 0 and 36),
  method      text not null check (method in ('mobile_money', 'cash', 'bank', 'other')),
  note        text,
  period_end  timestamptz not null,   -- nouvelle fin d'abonnement apres ce paiement
  recorded_by uuid references auth.users(id) default auth.uid(),
  paid_at     timestamptz not null default now()
);
create index if not exists subscription_payments_club_idx on public.subscription_payments (club_id, paid_at);
alter table public.subscription_payments enable row level security;
drop policy if exists subscription_payments_read on public.subscription_payments;
create policy subscription_payments_read on public.subscription_payments for select
  using (club_id = public.my_club() and public.is_patron());

-- ---------- Etat de l'abonnement d'un club ----------
-- 'actif' | 'bientot' (actif, mais <= 7 jours avant la fin) | 'grace' | 'bloque'
create or replace function public._club_etat(c public.clubs) returns text
language sql stable as $$
  select case
    when c.suspended then 'bloque'
    when c.expires_at is null then 'actif'
    when now() < c.expires_at - public.bario_grace() then 'actif'
    when now() < c.expires_at then 'bientot'
    when now() < c.expires_at + public.bario_grace() then 'grace'
    else 'bloque'
  end
$$;

-- Lu par l'application a chaque ouverture (n'importe quel membre de son club).
create or replace function public.subscription_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c public.clubs; v_etat text;
begin
  if public.is_platform_admin() then
    return jsonb_build_object('etat', 'actif', 'admin', true, 'bloquant', false);
  end if;
  select * into c from public.clubs where id = public.my_club();
  if not found then return jsonb_build_object('etat', 'sans_club', 'bloquant', true); end if;
  v_etat := public._club_etat(c);
  return jsonb_build_object(
    'etat', v_etat,
    'bloquant', v_etat = 'bloque',
    'patron', public.is_patron(),
    'club', c.name,
    'expire_le', c.expires_at,
    'grace_jours', extract(day from public.bario_grace())::int);
end $$;

-- Refuse d'agir quand l'abonnement est bloque (verif cote serveur).
create or replace function public._check_active() returns void
language plpgsql stable security definer set search_path = public as $$
declare c public.clubs;
begin
  if public.is_platform_admin() then return; end if;
  select * into c from public.clubs where id = public.my_club();
  if not found then raise exception 'ABONNEMENT: aucun club'; end if;
  if public._club_etat(c) = 'bloque' then
    raise exception 'ABONNEMENT_EXPIRE: abonnement termine, contactez votre fournisseur Bario';
  end if;
end $$;

-- On renforce les gardes de base : plus aucune action quand c'est bloque.
create or replace function public._require_member()
returns uuid language plpgsql stable security definer set search_path = public as $$
declare v uuid := public.my_member_id();
begin
  if v is null then raise exception 'Compte non autorise'; end if;
  perform public._check_active();
  return v;
end $$;

create or replace function public._require_staff()
returns uuid language plpgsql stable security definer set search_path = public as $$
declare v uuid := public._require_member();
begin
  if not public.is_staff() then raise exception 'Reserve au patron et au gerant'; end if;
  return v;
end $$;

-- ---------- Valeurs de depart d'un nouveau club ----------
create or replace function public._seed_club_defaults(p_club uuid, p_name text) returns void
language plpgsql security definer set search_path = public as $$
declare v_cat jsonb; v_cat_id uuid; v_ord int := 0; v_t text; v_torder int := 0;
begin
  -- Reglages
  insert into public.settings (club_id, club_name, ticket_header)
  values (p_club, p_name, upper(p_name))
  on conflict (club_id) do nothing;

  -- Categories de menu (vides : le patron ajoute ses boissons et prix)
  for v_t in select unnest(array[
      'Whiskies et liqueurs', 'Champagnes', 'Vins', 'Bieres',
      'Sodas et jus', 'Cocktails', 'Eau', 'Autres'])
  loop
    v_ord := v_ord + 1;
    insert into public.categories (club_id, name, sort_order)
    values (p_club, v_t, case when v_t = 'Autres' then 99 else v_ord end)
    on conflict (club_id, name) do nothing;
  end loop;

  -- Menu de base (boissons + prix) : voir 11_menu_boissons.sql.
  perform public._seed_club_menu(p_club);

  -- Quelques tables de depart
  for v_t in select unnest(array['VIP 1', 'VIP 2', 'Table 1', 'Table 2', 'Table 3', 'Table 4', 'Comptoir'])
  loop
    v_torder := v_torder + 1;
    insert into public.club_tables (club_id, name, zone, is_fixed, sort_order)
    values (p_club, v_t,
            case when v_t like 'VIP%' then 'vip' when v_t = 'Comptoir' then 'comptoir' else 'salle' end,
            true, v_torder)
    on conflict (club_id, name) do nothing;
  end loop;
end $$;

-- =====================================================================
-- Espace admin (toi)
-- =====================================================================

-- Creer un club + son patron, et fixer la date de fin d'abonnement.
-- Renvoie le code du club (a donner au client) et l'identifiant du patron.
create or replace function public.admin_create_club(
  p_club_name text,
  p_patron_login text,
  p_patron_pin text,
  p_patron_name text,
  p_phone text default null,
  p_months integer default 1,
  p_monthly_price integer default 25000
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_club uuid; v_code text; v_uid uuid; v_fin timestamptz;
begin
  perform public._exiger_admin();
  if coalesce(trim(p_club_name), '') = '' then raise exception 'Donnez un nom au club'; end if;
  perform public._check_login_pin(p_patron_login, p_patron_pin);
  if coalesce(trim(p_patron_name), '') = '' then raise exception 'Indiquez le nom du patron'; end if;
  if coalesce(p_months, 0) < 0 or p_months > 120 then raise exception 'Nombre de mois invalide'; end if;

  v_fin := case when coalesce(p_months, 0) > 0 then now() + make_interval(months => p_months) end;

  -- Code unique du club
  loop
    v_code := public._club_nouveau_code();
    exit when not exists (select 1 from public.clubs where code = v_code);
  end loop;

  insert into public.clubs (name, phone, code, monthly_price, expires_at)
  values (trim(p_club_name), p_phone, v_code, coalesce(p_monthly_price, 25000), v_fin)
  returning id into v_club;

  -- Le patron
  v_uid := public._create_auth_user(p_patron_login, p_patron_pin, v_code);
  update public.clubs set owner_user_id = v_uid where id = v_club;
  insert into public.members (club_id, user_id, login, role, display_name, phone)
  values (v_club, v_uid, lower(trim(p_patron_login)), 'patron', trim(p_patron_name), p_phone);

  perform public._seed_club_defaults(v_club, trim(p_club_name));

  return jsonb_build_object(
    'club_id', v_club, 'code', v_code,
    'patron_login', lower(trim(p_patron_login)),
    'expire_le', v_fin, 'mensuel', coalesce(p_monthly_price, 25000));
end $$;

-- Chiffres globaux
create or replace function public.admin_overview() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._exiger_admin();
  return (select jsonb_build_object(
    'clubs',        (select count(*) from public.clubs),
    'actifs',       (select count(*) from public.clubs c where public._club_etat(c) in ('actif','bientot')),
    'en_grace',     (select count(*) from public.clubs c where public._club_etat(c) = 'grace'),
    'bloques',      (select count(*) from public.clubs c where public._club_etat(c) = 'bloque'),
    'revenu_mensuel', (select coalesce(sum(monthly_price), 0) from public.clubs c
                        where public._club_etat(c) in ('actif','bientot','grace')),
    'encaisse_mois', (select coalesce(sum(amount), 0) from public.subscription_payments
                       where paid_at >= date_trunc('month', now())),
    'fin_proche',   (select count(*) from public.clubs c where public._club_etat(c) = 'bientot')
  ));
end $$;

-- Liste des clubs
create or replace function public.admin_clubs() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._exiger_admin();
  return coalesce((
    select jsonb_agg(x order by x->>'expire_le' nulls last) from (
      select jsonb_build_object(
        'id', c.id,
        'nom', c.name,
        'code', c.code,
        'cree_le', c.created_at,
        'etat', public._club_etat(c),
        'expire_le', c.expires_at,
        'mensuel', c.monthly_price,
        'suspendu', c.suspended,
        'patron', (select m.display_name from public.members m
                    where m.club_id = c.id and m.role = 'patron' limit 1),
        'telephone', c.phone,
        'derniere_soiree', (select max(n.opened_at) from public.nights n where n.club_id = c.id)
      ) as x
      from public.clubs c
    ) t
  ), '[]'::jsonb);
end $$;

-- Fiche d'un club (avec ses paiements)
create or replace function public.admin_club_detail(p_club_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._exiger_admin();
  return (select jsonb_build_object(
    'id', c.id, 'nom', c.name, 'code', c.code, 'cree_le', c.created_at,
    'etat', public._club_etat(c), 'expire_le', c.expires_at,
    'mensuel', c.monthly_price, 'suspendu', c.suspended, 'telephone', c.phone,
    'patron', (select m.display_name from public.members m where m.club_id = c.id and m.role = 'patron' limit 1),
    'patron_login', (select m.login from public.members m where m.club_id = c.id and m.role = 'patron' limit 1),
    'equipe', (select count(*) from public.members m where m.club_id = c.id and m.active),
    'paiements', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'montant', p.amount, 'mois', p.months, 'moyen', p.method,
        'note', p.note, 'le', p.paid_at, 'jusqu_au', p.period_end
      ) order by p.paid_at desc), '[]'::jsonb)
      from public.subscription_payments p where p.club_id = c.id)
  ) from public.clubs c where c.id = p_club_id);
end $$;

-- Paiement recu : prolonge l'abonnement de N mois (a la suite s'il reste de la grace, sinon depuis aujourd'hui).
create or replace function public.admin_record_payment(
  p_club_id uuid, p_amount integer, p_months integer, p_method text, p_note text default null
) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare c public.clubs; v_debut timestamptz; v_fin timestamptz;
begin
  perform public._exiger_admin();
  if coalesce(p_amount, 0) <= 0 then raise exception 'Indiquez le montant recu'; end if;
  if coalesce(p_months, 0) not between 1 and 36 then raise exception 'Nombre de mois invalide'; end if;
  select * into c from public.clubs where id = p_club_id for update;
  if not found then raise exception 'Club introuvable'; end if;

  v_debut := case when c.expires_at is null or c.expires_at < now() - public.bario_grace()
                  then now() else c.expires_at end;
  v_fin := v_debut + make_interval(months => p_months);
  update public.clubs set expires_at = v_fin, suspended = false where id = p_club_id;
  insert into public.subscription_payments (club_id, amount, months, method, note, period_end)
  values (p_club_id, p_amount, p_months, p_method, nullif(trim(p_note), ''), v_fin);
  return v_fin;
end $$;

-- Offrir des jours (prolonger, geste commercial)
create or replace function public.admin_extend(p_club_id uuid, p_days integer) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare c public.clubs; v_fin timestamptz;
begin
  perform public._exiger_admin();
  if coalesce(p_days, 0) not between 1 and 365 then raise exception 'Nombre de jours invalide'; end if;
  select * into c from public.clubs where id = p_club_id for update;
  if not found then raise exception 'Club introuvable'; end if;
  v_fin := greatest(coalesce(c.expires_at, now()), now()) + make_interval(days => p_days);
  update public.clubs set expires_at = v_fin where id = p_club_id;
  return v_fin;
end $$;

-- Date de fin precise (null = illimite)
create or replace function public.admin_set_expiry(p_club_id uuid, p_expires_at timestamptz) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._exiger_admin();
  update public.clubs set expires_at = p_expires_at where id = p_club_id;
  if not found then raise exception 'Club introuvable'; end if;
end $$;

-- Suspendre / reactiver a la main (blocage immediat)
create or replace function public.admin_set_suspended(p_club_id uuid, p_suspendre boolean) returns text
language plpgsql security definer set search_path = public as $$
declare c public.clubs;
begin
  perform public._exiger_admin();
  update public.clubs set suspended = coalesce(p_suspendre, false) where id = p_club_id
  returning * into c;
  if not found then raise exception 'Club introuvable'; end if;
  return public._club_etat(c);
end $$;

-- Prix mensuel personnalise (remise negociee)
create or replace function public.admin_set_price(p_club_id uuid, p_price integer) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._exiger_admin();
  if coalesce(p_price, -1) < 0 then raise exception 'Prix invalide'; end if;
  update public.clubs set monthly_price = p_price where id = p_club_id;
end $$;

-- Reinitialiser le PIN du patron d'un club (patron qui a oublie son code)
create or replace function public.admin_reset_patron_pin(p_club_id uuid, p_pin text) returns void
language plpgsql security definer set search_path = public, extensions, auth as $$
declare v_uid uuid;
begin
  perform public._exiger_admin();
  if coalesce(p_pin, '') !~ '^[0-9]{6}$' then raise exception 'Le code PIN doit contenir exactement 6 chiffres'; end if;
  select user_id into v_uid from public.members
   where club_id = p_club_id and role = 'patron' and active
   order by created_at limit 1;
  if v_uid is null then raise exception 'Patron introuvable'; end if;
  update auth.users set encrypted_password = extensions.crypt(p_pin, extensions.gen_salt('bf')),
                        updated_at = now()
   where id = v_uid;
end $$;

-- Supprimer un club de test (efface toutes ses donnees)
create or replace function public.admin_delete_club(p_club_id uuid) returns void
language plpgsql security definer set search_path = public, auth as $$
declare v_uid uuid;
begin
  perform public._exiger_admin();
  for v_uid in select user_id from public.members where club_id = p_club_id and user_id is not null loop
    delete from auth.users where id = v_uid;
  end loop;
  delete from public.clubs where id = p_club_id;   -- cascade sur toutes les tables du club
end $$;

-- ---------- Droits d'execution ----------
revoke execute on function public.bario_grace(), public._club_etat(public.clubs),
  public._check_active(), public._seed_club_defaults(uuid, text)
  from public, anon, authenticated;

revoke execute on function public.is_platform_admin(), public.subscription_status(),
  public.admin_create_club(text, text, text, text, text, integer, integer),
  public.admin_overview(), public.admin_clubs(), public.admin_club_detail(uuid),
  public.admin_record_payment(uuid, integer, integer, text, text),
  public.admin_extend(uuid, integer), public.admin_set_expiry(uuid, timestamptz),
  public.admin_set_suspended(uuid, boolean), public.admin_set_price(uuid, integer),
  public.admin_reset_patron_pin(uuid, text), public.admin_delete_club(uuid)
  from public, anon;
grant execute on function public.is_platform_admin(), public.subscription_status(),
  public.admin_create_club(text, text, text, text, text, integer, integer),
  public.admin_overview(), public.admin_clubs(), public.admin_club_detail(uuid),
  public.admin_record_payment(uuid, integer, integer, text, text),
  public.admin_extend(uuid, integer), public.admin_set_expiry(uuid, timestamptz),
  public.admin_set_suspended(uuid, boolean), public.admin_set_price(uuid, integer),
  public.admin_reset_patron_pin(uuid, text), public.admin_delete_club(uuid)
  to authenticated;

notify pgrst, 'reload schema';

-- ===== 10_correctif_settings.sql =====
-- =====================================================================
-- BARIO · Script 10 · Correctif : colonne id sur les reglages
-- A lancer UNE fois si tu as deja execute le script 01 dans sa premiere
-- version (ou tu peux simplement relancer le 01 corrige sur une base vide).
--
-- PowerSync a besoin d'une colonne « id » comme cle primaire sur chaque
-- table. La table settings etait la seule a ne pas en avoir. Sans donnees,
-- cette correction est sans risque.
-- =====================================================================

do $$
begin
  -- Ajoute la colonne id si elle manque
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'settings' and column_name = 'id') then
    alter table public.settings add column id uuid not null default gen_random_uuid();
    -- club_id n'est plus la cle primaire mais reste unique
    alter table public.settings drop constraint if exists settings_pkey;
    alter table public.settings add primary key (id);
    alter table public.settings add constraint settings_club_id_key unique (club_id);
    raise notice 'settings : colonne id ajoutee, club_id rendu unique';
  else
    raise notice 'settings : colonne id deja presente, rien a faire';
  end if;
end $$;

notify pgrst, 'reload schema';

-- ===== 11_menu_boissons.sql =====
-- =====================================================================
-- 11_menu_boissons.sql  —  Menu de base des boissons (Bario)
-- ---------------------------------------------------------------------
-- Charge un menu complet (categories + boissons + prix en FCFA) dans un
-- club. Les cocktails ne suivent pas le stock (faits a la demande).
--
--  * _seed_club_menu(club)       : charge le menu dans un club.
--  * admin_seed_menu(club)       : meme chose, depuis l'espace admin.
--  * Appel automatique a la creation d'un club (voir 08, _seed_club_defaults).
--  * En fin de fichier : chargement immediat dans les clubs deja crees.
--
-- Re-executable sans risque : « on conflict do nothing » n'ecrase jamais
-- un prix deja modifie par le patron.
-- =====================================================================

create or replace function public._seed_club_menu(p_club uuid) returns int
language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  -- Les categories (creees si elles manquent). « Autres » reste en dernier.
  insert into public.categories (club_id, name, sort_order) values
    (p_club, 'Whiskies et liqueurs', 1),
    (p_club, 'Champagnes',           2),
    (p_club, 'Vins',                 3),
    (p_club, 'Bieres',               4),
    (p_club, 'Sodas et jus',         5),
    (p_club, 'Cocktails',            6),
    (p_club, 'Eau',                  7),
    (p_club, 'Autres',              99)
  on conflict (club_id, name) do nothing;

  -- cat = categorie, nom = boisson, prix = prix de vente (FCFA),
  -- stock = suivre le stock ? (non pour les cocktails et le cafe), ord = ordre.
  with m(cat, nom, prix, stock, ord) as (values
    -- WHISKIES
    ('Whiskies et liqueurs', 'HIGHLAND PARK 12',            105000, true,  1),
    ('Whiskies et liqueurs', 'MACALLAN 12',                 110000, true,  2),
    ('Whiskies et liqueurs', 'GLENFIDDICH 12',               60000, true,  3),
    ('Whiskies et liqueurs', 'HENNESSY',                     60000, true,  4),
    ('Whiskies et liqueurs', 'DOUBLE BLACK 75cl',            60000, true,  5),
    ('Whiskies et liqueurs', 'GLENFIDDICH 15',               70000, true,  6),
    ('Whiskies et liqueurs', 'GRAND MARNIER',                70000, true,  7),
    ('Whiskies et liqueurs', 'AMARETTO',                     70000, true,  8),
    ('Whiskies et liqueurs', 'DOUBLE BLACK 1L',              65000, true,  9),
    ('Whiskies et liqueurs', 'REMY MARTIN',                  65000, true, 10),
    ('Whiskies et liqueurs', 'DON JULIO',                    75000, true, 11),
    ('Whiskies et liqueurs', 'BLACK LABEL',                  50000, true, 12),
    ('Whiskies et liqueurs', 'CHIVAS',                       50000, true, 13),
    ('Whiskies et liqueurs', 'DIMPLE',                       50000, true, 14),
    ('Whiskies et liqueurs', 'RED LABEL',                    40000, true, 15),
    ('Whiskies et liqueurs', 'JACK DANIEL''S',               40000, true, 16),
    ('Whiskies et liqueurs', 'BAILEYS',                      40000, true, 17),
    ('Whiskies et liqueurs', 'COGNAC VSOP XQ BOURGEOISIE',   50000, true, 18),
    ('Whiskies et liqueurs', 'GRANT''S',                     25000, true, 19),
    -- EAUX DE VIE (spiritueux)
    ('Whiskies et liqueurs', 'GORDON''S GIN',                30000, true, 20),
    ('Whiskies et liqueurs', 'BEEFEATER',                    30000, true, 21),
    ('Whiskies et liqueurs', 'ABSOLUT',                      25000, true, 22),
    ('Whiskies et liqueurs', 'RHUM ST JAMES',                25000, true, 23),
    ('Whiskies et liqueurs', 'RHUM BACARDI',                 25000, true, 24),
    ('Whiskies et liqueurs', 'COINTREAU',                    40000, true, 25),
    ('Whiskies et liqueurs', 'VODKA',                        20000, true, 26),
    ('Whiskies et liqueurs', 'VODKA BELVEDERE',              65000, true, 27),
    ('Whiskies et liqueurs', 'VODKA GREY GOOSE',             55000, true, 28),
    -- CHAMPAGNES
    ('Champagnes', 'LAURENT PERRIER',                        50000, true,  1),
    ('Champagnes', 'DUCHESSE',                               50000, true,  2),
    ('Champagnes', 'MOET CHANDON GOBILLARD & FILS',          60000, true,  3),
    ('Champagnes', 'MOET BRUT',                              65000, true,  4),
    ('Champagnes', 'RUINART BRUT',                           95000, true,  5),
    ('Champagnes', 'RUINART BLANC',                         145000, true,  6),
    ('Champagnes', 'VEUVE CLICQUOT',                         70000, true,  7),
    ('Champagnes', 'BELAIRE',                                45000, true,  8),
    -- VINS
    ('Vins', 'VIN I',                                        12000, true,  1),
    ('Vins', 'VIN II',                                       15000, true,  2),
    ('Vins', 'VIN MOUSSEUX I',                               15000, true,  3),
    ('Vins', 'VIN MOUSSEUX II',                              20000, true,  4),
    -- BIERES
    ('Bieres', 'PILS',                                        2000, true,  1),
    ('Bieres', 'DJAMA',                                       2000, true,  2),
    ('Bieres', 'BEAUFORT',                                    2000, true,  3),
    ('Bieres', 'GUINNESS',                                    2500, true,  4),
    ('Bieres', 'DESPERADOS',                                  2500, true,  5),
    ('Bieres', 'XXL',                                         2500, true,  6),
    ('Bieres', 'SMIRNOFF ICE',                                2500, true,  7),
    ('Bieres', 'RED''S',                                      2500, true,  8),
    ('Bieres', 'HEINEKEN',                                    2500, true,  9),
    -- SODAS ET JUS
    ('Sodas et jus', 'SODA',                                  1000, true,  1),
    ('Sodas et jus', 'TONIC',                                 1000, true,  2),
    ('Sodas et jus', 'COCA',                                  1000, true,  3),
    ('Sodas et jus', 'SPRITE',                                1000, true,  4),
    -- EAU
    ('Eau', 'EAU 50CL',                                        500, true,  1),
    -- COCKTAILS (sans suivi de stock)
    ('Cocktails', 'COCKTAIL MAISON',                          3500, false, 1),
    ('Cocktails', 'VIRGIN MOJITO',                            3500, false, 2),
    ('Cocktails', 'EXOTIC',                                   3500, false, 3),
    ('Cocktails', 'RED COLADA',                               3500, false, 4),
    ('Cocktails', 'COCKTAIL MAISON ALCOOLISE',               4500, false, 5),
    ('Cocktails', 'MASERATI VODKA',                           4500, false, 6),
    ('Cocktails', 'MOJITO ANANAS',                            4500, false, 7),
    ('Cocktails', 'MOJITO PASSION',                           4500, false, 8),
    ('Cocktails', 'PINA COLADA',                              4500, false, 9),
    -- AUTRES
    ('Autres', 'CAFE',                                        1500, false, 1)
  )
  insert into public.products (club_id, category_id, name, sale_price, track_stock, sort_order)
  select p_club, c.id, m.nom, m.prix, m.stock, m.ord
  from m
  join public.categories c on c.club_id = p_club and c.name = m.cat
  on conflict (club_id, category_id, name) do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end $$;

-- Depuis l'espace admin : (re)charger le menu de base dans un club.
create or replace function public.admin_seed_menu(p_club_id uuid) returns int
language plpgsql security definer set search_path = public as $$
begin
  perform public._exiger_admin();
  return public._seed_club_menu(p_club_id);
end $$;

revoke execute on function public._seed_club_menu(uuid), public.admin_seed_menu(uuid) from public, anon;
grant  execute on function public.admin_seed_menu(uuid) to authenticated;

-- Chargement immediat du menu dans les clubs deja crees.
select public._seed_club_menu(id) from public.clubs;

notify pgrst, 'reload schema';
