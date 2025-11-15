const SqlServerDriver = require('./drivers/sqlserver');

// Driver registry
const drivers = new Map();

/**
 * Get or create driver instance for connection string
 * @param {string} connectionString - Database connection string
 * @returns {BaseDriver} Driver instance
 */
function getDriver(connectionString) {
  // Check if driver already exists in registry
  if (drivers.has(connectionString)) {
    return drivers.get(connectionString);
  }

  // Determine driver type from connection string
  let driver;
  if (connectionString.startsWith('sqlserver://')) {
    driver = new SqlServerDriver(connectionString);
  } else if (connectionString.startsWith('postgres://')) {
    // TODO: PostgreSQL driver (Phase 8)
    throw new Error('PostgreSQL driver not yet implemented');
  } else if (connectionString.startsWith('mysql://')) {
    // TODO: MySQL driver (Phase 8)
    throw new Error('MySQL driver not yet implemented');
  } else if (connectionString.startsWith('sqlite://')) {
    // TODO: SQLite driver (Phase 8)
    throw new Error('SQLite driver not yet implemented');
  } else {
    throw new Error(`Unknown connection string format: ${connectionString}`);
  }

  // Store in registry
  drivers.set(connectionString, driver);
  return driver;
}

/**
 * Neovim remote plugin entry point
 * @param {Object} plugin - Neovim plugin instance
 */
module.exports = (plugin) => {
  console.error('[SSNS] Plugin initializing...');

  // Wrap in try-catch to catch any errors during registration
  try {
  /**
   * SSNSExecuteQuery - Execute SQL query and return structured results
   *
   * Usage from Lua:
   *   vim.fn['remote#host#FunctionCall']('node', 'SSNSExecuteQuery', {connection_string, query})
   *
   * @param {Array} args - [connectionString, query]
   * @returns {Promise<Object>} Result object with resultSets, metadata, error
   */
  plugin.registerFunction('SSNSExecuteQuery', async (args) => {
    try {
      // Handle double-wrapped array from Neovim
      const connectionString = Array.isArray(args[0]) ? args[0][0] : args[0];
      const query = Array.isArray(args[0]) ? args[0][1] : args[1];

      if (!connectionString || !query) {
        return {
          resultSets: [],
          metadata: {},
          error: {
            message: 'Missing required parameters: connectionString and query',
            code: null,
            lineNumber: null,
            procName: null
          }
        };
      }

      // Get driver for this connection
      const driver = getDriver(connectionString);

      // Execute query
      const result = await driver.execute(query);

      return result;

    } catch (err) {
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
  }, { sync: true }); // Changed to sync: true

  /**
   * SSNSGetMetadata - Get metadata for database object (for IntelliSense)
   *
   * Usage from Lua:
   *   vim.fn['remote#host#FunctionCall']('node', 'SSNSGetMetadata', {connection_string, object_type, object_name, schema_name})
   *
   * @param {Array} args - [connectionString, objectType, objectName, schemaName]
   * @returns {Promise<Object>} Metadata object with columns, indexes, constraints
   */
  plugin.registerFunction('SSNSGetMetadata', async (args) => {
    try {
      // Handle double-wrapped array from Neovim
      const connectionString = Array.isArray(args[0]) ? args[0][0] : args[0];
      const objectType = Array.isArray(args[0]) ? args[0][1] : args[1];
      const objectName = Array.isArray(args[0]) ? args[0][2] : args[2];
      const schemaName = Array.isArray(args[0]) ? args[0][3] : args[3];

      if (!connectionString || !objectType || !objectName) {
        return {
          columns: [],
          error: 'Missing required parameters: connectionString, objectType, and objectName'
        };
      }

      // Get driver for this connection
      const driver = getDriver(connectionString);

      // Get metadata
      const metadata = await driver.getMetadata(objectType, objectName, schemaName);

      return metadata;

    } catch (err) {
      return {
        columns: [],
        error: err.message || 'Unknown error occurred'
      };
    }
  }, { sync: true }); // Changed to sync: true

  /**
   * SSNSTestConnection - Test database connection
   *
   * Usage from Lua:
   *   vim.fn['remote#host#FunctionCall']('node', 'SSNSTestConnection', {connection_string})
   *
   * @param {Array} args - [connectionString]
   * @returns {Promise<Object>} { success: boolean, message: string }
   */
  plugin.registerFunction('SSNSTestConnection', async (args) => {
    console.error('[SSNS] SSNSTestConnection called');
    console.error('[SSNS] args:', JSON.stringify(args));
    console.error('[SSNS] args length:', args.length);
    console.error('[SSNS] args[0]:', args[0]);
    console.error('[SSNS] args[0] type:', typeof args[0]);
    console.error('[SSNS] args[0] isArray:', Array.isArray(args[0]));

    if (Array.isArray(args[0])) {
      console.error('[SSNS] args[0][0]:', args[0][0]);
      console.error('[SSNS] args[0][0] type:', typeof args[0][0]);
    }

    try {
      // If Neovim double-wraps the array, unwrap it
      const connectionString = Array.isArray(args[0]) ? args[0][0] : args[0];
      console.error('[SSNS] Final connectionString:', connectionString, 'type:', typeof connectionString);

      if (!connectionString) {
        console.error('[SSNS] No connection string provided');
        return {
          success: false,
          message: 'Missing required parameter: connectionString'
        };
      }

      console.error('[SSNS] Getting driver for:', connectionString);
      // Get driver for this connection
      const driver = getDriver(connectionString);

      console.error('[SSNS] Testing connection...');
      // Test connection
      await driver.connect();

      console.error('[SSNS] Connection successful!');
      return {
        success: true,
        message: 'Connection successful'
      };

    } catch (err) {
      console.error('[SSNS] Connection failed:', err.message);
      return {
        success: false,
        message: err.message || 'Connection failed'
      };
    }
  }, { sync: true }); // Changed to sync: true

  /**
   * SSNSCloseConnection - Close database connection
   *
   * Usage from Lua:
   *   vim.fn['remote#host#FunctionCall']('node', 'SSNSCloseConnection', {connection_string})
   *
   * @param {Array} args - [connectionString]
   * @returns {Promise<Object>} { success: boolean }
   */
  plugin.registerFunction('SSNSCloseConnection', async (args) => {
    try {
      // Handle double-wrapped array from Neovim
      const connectionString = Array.isArray(args[0]) ? args[0][0] : args[0];

      if (!connectionString) {
        return { success: false };
      }

      // Get driver from registry
      const driver = drivers.get(connectionString);
      if (driver) {
        await driver.disconnect();
        drivers.delete(connectionString);
      }

      return { success: true };

    } catch (err) {
      return { success: false };
    }
  }, { sync: true }); // Changed to sync: true

  console.error('[SSNS] All functions registered successfully');

  } catch (err) {
    console.error('[SSNS] ERROR during plugin initialization:', err);
    console.error('[SSNS] Stack:', err.stack);
    throw err;
  }
};
