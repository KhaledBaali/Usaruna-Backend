-- ============================================================
-- Usaruna (أسرنا) — Supabase Database Schema
-- Run this SQL in your Supabase SQL Editor to create all tables.
-- Dashboard → SQL Editor → New query → paste → Run
-- ============================================================

-- ── Cities reference table ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cities (
  id        SERIAL PRIMARY KEY,
  name_ar   TEXT NOT NULL UNIQUE,
  name_en   TEXT NOT NULL,
  region_ar TEXT,
  region_en TEXT,
  is_active BOOLEAN DEFAULT true
);

-- ── Producer profiles (extends auth.users for sellers) ────────────────────────
CREATE TABLE IF NOT EXISTS producer_profiles (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name_ar       TEXT NOT NULL,          -- family name in Arabic
  name_en       TEXT,                   -- family name in English
  owner_name    TEXT,
  phone         TEXT,
  city_ar       TEXT NOT NULL,
  city_en       TEXT,
  category      TEXT,                   -- 'food', 'sweets', 'honey', 'handmade', etc.
  bio_ar        TEXT,
  bio_en        TEXT,
  whatsapp      TEXT,
  partner_since TEXT,                   -- e.g. "مارس 2022" / "March 2022"
  avatar_url    TEXT,
  rating        NUMERIC(3,2) DEFAULT 0,
  total_reviews INTEGER DEFAULT 0,
  is_verified   BOOLEAN DEFAULT false,
  is_active     BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- ── Products ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
  id                  SERIAL PRIMARY KEY,
  producer_id         UUID REFERENCES producer_profiles(id) ON DELETE CASCADE,
  name_ar             TEXT NOT NULL,
  name_en             TEXT,
  description_ar      TEXT,
  description_en      TEXT,
  price               NUMERIC(10,2) NOT NULL,
  original_price      NUMERIC(10,2),
  badge_ar            TEXT,
  badge_en            TEXT,
  badge_color         TEXT DEFAULT 'bg-amber-500',
  emoji               TEXT DEFAULT '📦',
  gradient            TEXT DEFAULT 'from-blue-200 to-blue-100',
  weight_ar           TEXT,
  weight_en           TEXT,
  preparation_time_ar TEXT,
  preparation_time_en TEXT,
  is_perishable       BOOLEAN DEFAULT false,
  stock               INTEGER DEFAULT 0,
  order_cutoff        TEXT,             -- "21:00"
  certifications_ar   TEXT[],           -- ['طبيعي']
  certifications_en   TEXT[],           -- ['Natural']
  sizes               JSONB,            -- [{ id, label_ar, label_en, price_adj }]
  colors              JSONB,            -- [{ id, label_ar, label_en, hex }] or null
  is_refundable       BOOLEAN DEFAULT false,
  refund_policy_ar    TEXT,
  refund_policy_en    TEXT,
  specifications_ar   JSONB,            -- { "المكونات": "..." }
  specifications_en   JSONB,            -- { "Ingredients": "..." }
  images              TEXT[],           -- emoji placeholders
  image_urls          TEXT[],           -- real uploaded image paths
  rating              NUMERIC(3,2) DEFAULT 0,
  review_count        INTEGER DEFAULT 0,
  is_active           BOOLEAN DEFAULT true,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

-- ── Reviews ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reviews (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id           INTEGER REFERENCES products(id) ON DELETE CASCADE,
  user_id              UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  author_name_ar       TEXT NOT NULL DEFAULT 'مستخدم',
  author_name_en       TEXT NOT NULL DEFAULT 'User',
  rating               SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment_ar           TEXT,
  comment_en           TEXT,
  is_verified_purchase BOOLEAN DEFAULT false,
  helpful_count        INTEGER DEFAULT 0,
  created_at_label_ar  TEXT,            -- pre-formatted "28 أبريل 2025"
  created_at_label_en  TEXT,            -- pre-formatted "April 28, 2025"
  created_at           TIMESTAMPTZ DEFAULT now()
);

-- ── Orders ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS orders (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  product_id     INTEGER REFERENCES products(id) ON DELETE SET NULL,
  producer_id    UUID REFERENCES producer_profiles(id) ON DELETE SET NULL,
  quantity       INTEGER NOT NULL DEFAULT 1,
  size_id        TEXT,
  color_id       TEXT,
  delivery_type  TEXT DEFAULT 'third_party',
  total_price    NUMERIC(10,2) NOT NULL,
  status         TEXT DEFAULT 'pending',  -- pending, accepted, shipped, delivered, cancelled
  payment_status TEXT DEFAULT 'pending',  -- pending, paid, refunded
  notes          TEXT,
  created_at     TIMESTAMPTZ DEFAULT now(),
  updated_at     TIMESTAMPTZ DEFAULT now()
);

-- ── Indexes ───────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_products_producer   ON products(producer_id);
CREATE INDEX IF NOT EXISTS idx_products_active     ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_perishable ON products(is_perishable);
CREATE INDEX IF NOT EXISTS idx_reviews_product     ON reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_orders_user         ON orders(user_id);

-- ── Row Level Security ────────────────────────────────────────────────────────
ALTER TABLE cities            ENABLE ROW LEVEL SECURITY;
ALTER TABLE producer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE products          ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews           ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders            ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read cities"             ON cities            FOR SELECT USING (is_active = true);
CREATE POLICY "Public read producers"          ON producer_profiles FOR SELECT USING (is_active = true);
CREATE POLICY "Public read active products"    ON products          FOR SELECT USING (is_active = true);
CREATE POLICY "Public read reviews"            ON reviews           FOR SELECT USING (true);
CREATE POLICY "Auth users can write reviews"   ON reviews           FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users read own orders"          ON orders            FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Auth users can place orders"    ON orders            FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ── Seed: Cities ──────────────────────────────────────────────────────────────
INSERT INTO cities (name_ar, name_en, region_ar, region_en) VALUES
  ('الرياض',          'Riyadh',    'منطقة الرياض',    'Riyadh Region'),
  ('جدة',             'Jeddah',    'منطقة مكة',       'Mecca Region'),
  ('مكة المكرمة',     'Mecca',     'منطقة مكة',       'Mecca Region'),
  ('المدينة المنورة', 'Medina',    'منطقة المدينة',   'Medina Region'),
  ('الدمام',          'Dammam',    'المنطقة الشرقية', 'Eastern Region'),
  ('القصيم',          'Qassim',    'منطقة القصيم',    'Qassim Region'),
  ('تبوك',            'Tabuk',     'منطقة تبوك',      'Tabuk Region'),
  ('أبها',            'Abha',      'منطقة عسير',      'Aseer Region'),
  ('حائل',            'Ha''il',    'منطقة حائل',      'Ha''il Region'),
  ('ينبع',            'Yanbu',     'منطقة المدينة',   'Medina Region'),
  ('الباحة',          'Al Baha',   'منطقة الباحة',    'Al Baha Region'),
  ('الأحساء',         'Al-Ahsa',   'المنطقة الشرقية', 'Eastern Region'),
  ('بريدة',           'Buraydah',  'منطقة القصيم',    'Qassim Region')
ON CONFLICT (name_ar) DO NOTHING;
