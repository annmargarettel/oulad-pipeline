%sql
-- Sets up the catalog and schemas

-- Create catalog: oulad 
CREATE CATALOG IF NOT EXISTS oulad;

-- Create schema for bronze layer - data ingestions
CREATE SCHEMA IF NOT EXISTS oulad.raw;

-- Create schema for silver layer - data cleaning
CREATE SCHEMA IF NOT EXISTS oulad.clean;

-- Create schema for mart layer - dimensional modelling
CREATE SCHEMA IF NOT EXISTS oulad.mart;

-- Create schema for dashboard visualizations
CREATE SCHEMA IF NOT EXISTS oulad.bi_visualization;

-- Create schema for data quality checks
CREATE SCHEMA IF NOT EXISTS oulad.validation;

-- Create schema for data quality checks
CREATE SCHEMA IF NOT EXISTS oulad.dq_visualization;

SHOW SCHEMAS;