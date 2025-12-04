
const DriverFactory = require('./drivers/factory');
const { ssnsLog } = require('./ssns-log');

// Driver registry - reuse drivers for same connections
const drivers = new Map();

/**
 * Generate a connection key from config for driver registry
 * @param {Object} config - Connection configuration object
 * @returns {string} Unique key for this connection
 */
function generateConnectionKey(config) {
  const parts = [config.type];

  if (config.server) {
    parts.push(config.server.host || '');
    if (config.server.instance) parts.push(config.server.instance);
    if (config.server.port) parts.push(String(config.server.port));
    if (config.server.database) parts.push(config.server.database);
  }

  if (config.auth) {
    parts.push(config.auth.type || '');
    if (config.auth.username) parts.push(config.auth.username);
  }

  return parts.join(':');
}

/**
 * Get or create driver instance for connection config
 * @param {Object} config - Connection configuration object
 * @returns {BaseDriver} Driver instance
 */
function getDriverInstance(config) {
  const key = generateConnectionKey(config);

  // Check if driver already exists in registry
  if (drivers.has(key)) {
    return drivers.get(key);
  }

  // Use factory to create appropriate driver
  const driver = DriverFactory.getDriver(config);

  // Store in registry for reuse
  drivers.set(key, driver);
  return driver;
}

/**
 * Parse config from JSON string or return as-is if already object
 * @param {string|Object} configInput - JSON string or config object
 * @returns {Object} Parsed config object
 */
function parseConfig(configInput) {
  if (typeof configInput === 'string') {
    return JSON.parse(configInput);
  }
  return configInput;
}

/**
 * Neovim remote plugin entry point
 * @param {Object} plugin - Neovim plugin instance
 */

module.exports = (plugin) => {
  ssnsLog('[SSNS] Plugin initializing...');

  // Wrap in try-catch to catch any errors during registration
  try {
  /**
   * SSNSExecuteQuery - Execute SQL query and return structured results
   *
   * Usage from Lua:
   *   vim.fn['remote#host#FunctionCall']('node', 'SSNSExecuteQuery', {config_json, query})
   *
   * @param {Array} args - [configJson, query]
   * @returns {Promise<Object>} Result object with resultSets, metadata, error
   */
  plugin.registerFunction('SSNSExecuteQuery', async (args) => {
    try {
      // Handle double-wrapped array from Neovim
      const configInput = Array.isArray(args[0]) ? args[0][0] : args[0];
      const query = Array.isArray(args[0]) ? args[0][1] : args[1];

      if (!configInput || !query) {
        return {
          resultSets: [],
          metadata: {},
          error: {
            message: 'Missing required parameters: config and query',
            code: null,
            lineNumber: null,
            procName: null
          }
        };
      }

      // Parse config from JSON
      const config = parseConfig(configInput);

      // Get driver for this connection
      const driver = getDriverInstance(config);

      // Execute query
      const result = await driver.execute(query);

      return result;

    } catch (err) {
      ssnsLog(`[SSNSExecuteQuery] Error: ${err && err.stack ? err.stack : err}`);
      return {
        resultSets: [],
        metadata: {},
        error: {
          message: err.message || 'Unknown error occurred',
          code: err.code || null,
          lineNumber: err.lineNumber || null,
          procName: err.procName || null
        }
      };
    }
  }, { sync: true });

  /**
   * SSNSGetMetadata - Get metadata for database object (for IntelliSense)
   *
   * Usage from Lua:
   *   vim.fn['remote#host#FunctionCall']('node', 'SSNSGetMetadata', {config_json, object_type, object_name, schema_name})
   *
   * @param {Array} args - [configJson, objectType, objectName, schemaName]
   * @returns {Promise<Object>} Metadata object with columns, indexes, constraints
   */
  plugin.registerFunction('SSNSGetMetadata', async (args) => {
    try {
      // Handle double-wrapped array from Neovim
      const configInput = Array.isArray(args[0]) ? args[0][0] : args[0];
      const objectType = Array.isArray(args[0]) ? args[0][1] : args[1];
      const objectName = Array.isArray(args[0]) ? args[0][2] : args[2];
      const schemaName = Array.isArray(args[0]) ? args[0][3] : args[3];

      if (!configInput || !objectType || !objectName) {
        return {
          columns: [],
          error: 'Missing required parameters: config, objectType, and objectName'
        };
      }

      // Parse config from JSON
      const config = parseConfig(configInput);

      // Get driver for this connection
      const driver = getDriverInstance(config);

      // Get metadata
      const metadata = await driver.getMetadata(objectType, objectName, schemaName);

      return metadata;

    } catch (err) {
      ssnsLog(`[SSNSGetMetadata] Error: ${err && err.stack ? err.stack : err}`);
      return {
        columns: [],
        error: err.message || 'Unknown error occurred'
      };
    }
  }, { sync: true });

  /**
   * SSNSTestConnection - Test database connection
   *
   * Usage from Lua:
   *   vim.fn['remote#host#FunctionCall']('node', 'SSNSTestConnection', {config_json})
   *
   * @param {Array} args - [configJson]
   * @returns {Promise<Object>} { success: boolean, message: string }
   */
  plugin.registerFunction('SSNSTestConnection', async (args) => {
    ssnsLog('[index] SSNSTestConnection called');
    ssnsLog(`[index] args: ${JSON.stringify(args)}`);

    try {
      // If Neovim double-wraps the array, unwrap it
      const configInput = Array.isArray(args[0]) ? args[0][0] : args[0];
      ssnsLog(`[index] Config input type: ${typeof configInput}`);

      if (!configInput) {
        ssnsLog('[index] No config provided');
        return {
          success: false,
          message: 'Missing required parameter: config'
        };
      }

      // Parse config from JSON
      const config = parseConfig(configInput);
      ssnsLog(`[index] Parsed config type: ${config.type}`);

      ssnsLog('[index] Getting driver...');
      // Get driver for this connection
      const driver = getDriverInstance(config);

      ssnsLog('[index] Testing connection...');
      // Test connection
      await driver.connect();

      ssnsLog('[index] Connection successful!');
      return {
        success: true,
        message: 'Connection successful'
      };

    } catch (err) {
      ssnsLog(`[index] Connection failed: ${err.message}`);
      return {
        success: false,
        message: err.message || 'Connection failed'
      };
    }
  }, { sync: true });

  /**
   * SSNSCloseConnection - Close database connection
   *
   * Usage from Lua:
   *   vim.fn['remote#host#FunctionCall']('node', 'SSNSCloseConnection', {config_json})
   *
   * @param {Array} args - [configJson]
   * @returns {Promise<Object>} { success: boolean }
   */
  plugin.registerFunction('SSNSCloseConnection', async (args) => {
    try {
      // Handle double-wrapped array from Neovim
      const configInput = Array.isArray(args[0]) ? args[0][0] : args[0];

      if (!configInput) {
        return { success: false };
      }

      // Parse config from JSON
      const config = parseConfig(configInput);
      const key = generateConnectionKey(config);

      // Get driver from registry
      const driver = drivers.get(key);
      if (driver) {
        await driver.disconnect();
        drivers.delete(key);
      }

      return { success: true };

    } catch (err) {
      return { success: false };
    }
  }, { sync: true });

  ssnsLog('[index] All functions registered successfully');

  } catch (err) {
    ssnsLog(`[index] ERROR during plugin initialization: ${err && err.stack ? err.stack : err}`);
    throw err;
  }
};
