/**
 * Driver Factory - Create the appropriate database driver based on config type
 *
 * Supports:
 * - SQL Server (type: "sqlserver")
 * - MySQL (type: "mysql")
 * - SQLite (type: "sqlite")
 * - PostgreSQL (type: "postgres")
 */
const { ssnsLog } = require('../ssns-log');
const SqlServerDriver = require('./sqlserver');
const MySQLDriver = require('./mysql');
const SQLiteDriver = require('./sqlite');
const PostgresDriver = require('./postgres');

/**
 * Get the appropriate driver for a connection config
 *
 * @param {Object} config - Connection configuration object
 * @param {string} config.type - Database type ("sqlserver", "mysql", "sqlite", "postgres")
 * @param {Object} config.server - Server connection details
 * @param {Object} config.auth - Authentication details
 * @param {Object} [config.options] - Additional connection options
 * @returns {BaseDriver} Driver instance
 * @throws {Error} If config is invalid or type is unsupported
 */
function getDriver(config) {
  ssnsLog(`[factory] getDriver called with config type: ${config && config.type}`);

  if (!config || typeof config !== 'object') {
    ssnsLog('[factory] Invalid config: must be a non-empty object');
    throw new Error('Invalid config: must be a non-empty object');
  }

  if (!config.type) {
    ssnsLog('[factory] Invalid config: missing type field');
    throw new Error('Invalid config: missing type field');
  }

  const dbType = config.type.toLowerCase();

  // SQL Server
  if (dbType === 'sqlserver' || dbType === 'mssql') {
    ssnsLog('[factory] Creating SQL Server driver');
    return new SqlServerDriver(config);
  }

  // MySQL
  if (dbType === 'mysql') {
    ssnsLog('[factory] Creating MySQL driver');
    return new MySQLDriver(config);
  }

  // SQLite
  if (dbType === 'sqlite') {
    ssnsLog('[factory] Creating SQLite driver');
    return new SQLiteDriver(config);
  }

  // PostgreSQL
  if (dbType === 'postgres' || dbType === 'postgresql') {
    ssnsLog('[factory] Creating PostgreSQL driver');
    return new PostgresDriver(config);
  }

  // Unknown database type
  ssnsLog(`[factory] Unsupported database type: ${config.type}`);
  throw new Error(
    `Unsupported database type: ${config.type}\n` +
    `Supported types:\n` +
    `  - sqlserver\n` +
    `  - mysql\n` +
    `  - sqlite\n` +
    `  - postgres`
  );
}

/**
 * Check if a database type is supported
 *
 * @param {string} dbType - Database type to check
 * @returns {boolean} True if supported
 */
function isSupported(dbType) {
  ssnsLog(`[factory] isSupported called with: ${dbType}`);
  const supported = ['sqlserver', 'mssql', 'mysql', 'sqlite', 'postgres', 'postgresql'];
  const result = supported.includes(dbType.toLowerCase());
  ssnsLog(`[factory] isSupported result: ${result}`);
  return result;
}

/**
 * Get list of supported database types
 *
 * @returns {Array<string>} List of supported database types
 */
function getSupportedTypes() {
  ssnsLog('[factory] getSupportedTypes called');
  return ['sqlserver', 'mysql', 'sqlite', 'postgres'];
}

module.exports = {
  getDriver,
  isSupported,
  getSupportedTypes
};
