-- CreateEnum
CREATE TYPE "Role" AS ENUM ('DEFAULT', 'ROOT', 'ADMIN', 'DEMO', 'API', 'SYSTEM');

-- CreateEnum
CREATE TYPE "Gender" AS ENUM ('MALE', 'FEMALE', 'OTHER');

-- CreateEnum
CREATE TYPE "Person_Type" AS ENUM ('COSTUMER', 'SUPPLIER');

-- CreateEnum
CREATE TYPE "Origin" AS ENUM ('RAW_MATERIAL', 'MADE', 'CONSUMABLE', 'OTHER');

-- CreateEnum
CREATE TYPE "Unit_Measure" AS ENUM ('UN', 'PC', 'PCT', 'ML', 'L', 'GR', 'KG', 'TON');

-- CreateEnum
CREATE TYPE "Price_Type" AS ENUM ('COST', 'SALE');

-- CreateEnum
CREATE TYPE "Stock_Moviment" AS ENUM ('INPUT', 'TRANSIT', 'OUTPUT', 'RESERVED', 'BALANCE', 'ADJUST', 'INVENTORY');

-- CreateEnum
CREATE TYPE "Production_Status" AS ENUM ('CREATED', 'SCHEDULED', 'OPEN', 'IN_PROGRESS', 'FINISHED', 'STOPPED', 'CANCELED');

-- CreateEnum
CREATE TYPE "Owner" AS ENUM ('PRODUCT', 'PRODUCTION_STEP', 'STOCK_ITEM', 'OCURRENCE');

-- CreateTable
CREATE TABLE "users" (
    "id" SERIAL NOT NULL,
    "email" VARCHAR(255) NOT NULL,
    "password" VARCHAR(255) NOT NULL,
    "role" "Role" NOT NULL DEFAULT 'DEFAULT',
    "username" VARCHAR(255) NOT NULL,
    "first_name" VARCHAR(255),
    "last_name" VARCHAR(255),
    "gender" "Gender" DEFAULT 'OTHER',
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "persons" (
    "id" SERIAL NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "type" "Person_Type" NOT NULL DEFAULT 'SUPPLIER',
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "persons_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "products" (
    "id" SERIAL NOT NULL,
    "description" VARCHAR(255) NOT NULL,
    "code" VARCHAR(255) NOT NULL,
    "unit_measure" "Unit_Measure" NOT NULL DEFAULT 'KG',
    "category_id" INTEGER NOT NULL DEFAULT 1,
    "group_id" INTEGER NOT NULL DEFAULT 1,
    "supplier_id" INTEGER,
    "nutritional_info" JSONB,
    "images" INTEGER[],
    "active" BOOLEAN NOT NULL DEFAULT true,
    "origin" "Origin" NOT NULL DEFAULT 'RAW_MATERIAL',
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "products_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "categories" (
    "id" SERIAL NOT NULL,
    "description" VARCHAR(255) NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "prices" (
    "id" SERIAL NOT NULL,
    "product_id" INTEGER NOT NULL,
    "price" DOUBLE PRECISION NOT NULL,
    "type" "Price_Type" NOT NULL DEFAULT 'COST',
    "is_current" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "prices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stock" (
    "id" SERIAL NOT NULL,
    "document_number" VARCHAR(255) NOT NULL,
    "document_date" TIMESTAMP(6) NOT NULL,
    "stock_moviment" "Stock_Moviment" NOT NULL,
    "document_type" VARCHAR(255),
    "is_balance" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "stock_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stock_location" (
    "id" SERIAL NOT NULL,
    "description" VARCHAR(255) NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "stock_location_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stock_items" (
    "id" SERIAL NOT NULL,
    "stock_id" INTEGER NOT NULL,
    "sequence" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "quantity" DOUBLE PRECISION NOT NULL,
    "unit_price" DOUBLE PRECISION NOT NULL,
    "total_price" DOUBLE PRECISION NOT NULL,
    "batch" TEXT,
    "batch_expiration" TIMESTAMP(3),
    "sku" VARCHAR(255) NOT NULL,
    "images" INTEGER[],
    "supplier" INTEGER,
    "costumer" INTEGER,
    "stock_location_id" INTEGER NOT NULL,
    "observation" TEXT,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "stock_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "production_orders" (
    "id" SERIAL NOT NULL,
    "number" INTEGER NOT NULL,
    "description" VARCHAR(255),
    "production_date" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "production_line" VARCHAR(255),
    "Production_Status" "Production_Status" NOT NULL DEFAULT 'CREATED',
    "final_product_id" INTEGER NOT NULL,
    "production_quantity_estimated" DOUBLE PRECISION NOT NULL,
    "production_quantity_real" DOUBLE PRECISION NOT NULL,
    "production_quantity_loss" DOUBLE PRECISION NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "production_orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "production_orders_items" (
    "id" SERIAL NOT NULL,
    "production_order_id" INTEGER NOT NULL,
    "sequence" INTEGER NOT NULL,
    "raw_product_id" INTEGER NOT NULL,
    "raw_product_initial_quantity" DOUBLE PRECISION NOT NULL,
    "raw_product_used_quantity" DOUBLE PRECISION NOT NULL,
    "used_batchs" JSONB NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "production_orders_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "production_order_steps" (
    "id" SERIAL NOT NULL,
    "description" VARCHAR(255) NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "production_order_steps_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "production_steps_progress" (
    "id" SERIAL NOT NULL,
    "production_id" INTEGER NOT NULL,
    "step_id" INTEGER NOT NULL,
    "sequence" INTEGER NOT NULL,
    "raw_product_id" INTEGER NOT NULL,
    "start_time" TIMESTAMP(3),
    "end_time" TIMESTAMP(3),
    "total_time" DOUBLE PRECISION,
    "initial_quantity" DOUBLE PRECISION,
    "final_quantity" DOUBLE PRECISION,
    "quantity_loss" DOUBLE PRECISION,
    "machine" TEXT,
    "production_line" TEXT,
    "images" INTEGER[],
    "observation" TEXT,
    "operator" TEXT,
    "occurrences" JSON,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "production_steps_progress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "occurrences_of_production_stages" (
    "id" SERIAL NOT NULL,
    "occurrence_id" INTEGER NOT NULL,
    "description" VARCHAR(255) NOT NULL,
    "observation" TEXT,
    "images" INTEGER[],
    "stage_occurred_id" INTEGER NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "occurrences_of_production_stages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "occurrences" (
    "id" SERIAL NOT NULL,
    "description" VARCHAR(255) NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "occurrences_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "settings" (
    "id" SERIAL NOT NULL,
    "key" VARCHAR(255) NOT NULL,
    "value" TEXT NOT NULL,
    "description" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT NOT NULL,
    "updated_by" TEXT NOT NULL,

    CONSTRAINT "settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "compositions" (
    "id" SERIAL NOT NULL,
    "final_product" INTEGER NOT NULL,
    "description" VARCHAR(255) NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,
    "production_steps" JSONB,

    CONSTRAINT "compositions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "composition_items" (
    "id" SERIAL NOT NULL,
    "composition_id" INTEGER NOT NULL,
    "sequence" INTEGER NOT NULL,
    "raw_product" INTEGER NOT NULL,
    "quantity" DOUBLE PRECISION NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "composition_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "groups" (
    "id" SERIAL NOT NULL,
    "description" VARCHAR(255) NOT NULL,
    "father_id" INTEGER,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "groups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "images" (
    "id" SERIAL NOT NULL,
    "hash" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "mime_type" TEXT NOT NULL,
    "file_name" TEXT NOT NULL,
    "original_name" TEXT NOT NULL,
    "size" INTEGER NOT NULL,
    "width" INTEGER NOT NULL,
    "height" INTEGER NOT NULL,
    "metadata" JSONB,
    "owner" "Owner" NOT NULL,
    "owner_id" INTEGER NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "updated_by" TEXT,

    CONSTRAINT "images_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_username_key" ON "users"("username");

-- CreateIndex
CREATE UNIQUE INDEX "products_code_key" ON "products"("code");

-- CreateIndex
CREATE UNIQUE INDEX "categories_description_key" ON "categories"("description");

-- CreateIndex
CREATE UNIQUE INDEX "stock_document_number_key" ON "stock"("document_number");

-- CreateIndex
CREATE UNIQUE INDEX "stock_items_sku_key" ON "stock_items"("sku");

-- CreateIndex
CREATE UNIQUE INDEX "production_orders_number_key" ON "production_orders"("number");

-- CreateIndex
CREATE UNIQUE INDEX "settings_key_key" ON "settings"("key");

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "persons"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prices" ADD CONSTRAINT "prices_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_items" ADD CONSTRAINT "stock_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_items" ADD CONSTRAINT "stock_items_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "stock"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_items" ADD CONSTRAINT "stock_items_stock_location_id_fkey" FOREIGN KEY ("stock_location_id") REFERENCES "stock_location"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_items" ADD CONSTRAINT "stock_items_supplier_fkey" FOREIGN KEY ("supplier") REFERENCES "persons"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_items" ADD CONSTRAINT "stock_items_costumer_fkey" FOREIGN KEY ("costumer") REFERENCES "persons"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "production_orders_items" ADD CONSTRAINT "final_product_fkey" FOREIGN KEY ("raw_product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "production_orders_items" ADD CONSTRAINT "production_orders_items_production_order_id_fkey" FOREIGN KEY ("production_order_id") REFERENCES "production_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "production_steps_progress" ADD CONSTRAINT "production_steps_progress_production_id_fkey" FOREIGN KEY ("production_id") REFERENCES "production_orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "production_steps_progress" ADD CONSTRAINT "production_steps_progress_raw_product_id_fkey" FOREIGN KEY ("raw_product_id") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "production_steps_progress" ADD CONSTRAINT "production_steps_progress_step_id_fkey" FOREIGN KEY ("step_id") REFERENCES "production_order_steps"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "occurrences_of_production_stages" ADD CONSTRAINT "occurrences_of_production_stages_occurrence_id_fkey" FOREIGN KEY ("occurrence_id") REFERENCES "occurrences"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "occurrences_of_production_stages" ADD CONSTRAINT "occurrences_of_production_stages_stage_occurred_id_fkey" FOREIGN KEY ("stage_occurred_id") REFERENCES "production_steps_progress"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "compositions" ADD CONSTRAINT "compositions_final_product_fkey" FOREIGN KEY ("final_product") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "composition_items" ADD CONSTRAINT "composition_items_composition_id_fkey" FOREIGN KEY ("composition_id") REFERENCES "compositions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "composition_items" ADD CONSTRAINT "composition_items_raw_product_fkey" FOREIGN KEY ("raw_product") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "groups" ADD CONSTRAINT "groups_father_id_fkey" FOREIGN KEY ("father_id") REFERENCES "groups"("id") ON DELETE SET NULL ON UPDATE CASCADE;
