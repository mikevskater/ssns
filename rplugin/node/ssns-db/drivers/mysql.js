const mysql = require('mysql2/promise');
const BaseDriver = require('./base');

/**
 * MySQLDriver - MySQL database driver using mysql2 package
 *
 * Provides MySQL connectivity with:
 * - Connection pooling
 * - Promise-based API
 * - Structured errors
 * - Column metadata
 */
class MySQLDriver extends BaseDriver {
  /**
   * @param {Object} config - Connection configuration object
   * @param {string} config.type - "mysql"
   * @param {Object} config.server - Server details
   * @param {string} config.server.host - Server hostname or IP
   * @param {number} [config.server.port] - Port number (default: 3306)
   * @param {string} [config.server.database] - Database name
   * @param {Object} config.auth - Authentication details
   * @param {string} [config.auth.username] - Username (default: root)
   * @param {string} [config.auth.password] - Password
   * @param {Object} [config.options] - Additional options
   * @param {boolean} [config.options.ssl] - Use SSL
   */
  constructor(config) {
    super(config);
    this.mysqlConfig = this.buildMysqlConfig(config);
  }

  /**
   * Build mysql2 configuration from connection config
   *
   * @param {Object} config - Connection configuration
   * @returns {Object} mysql2 config object
   */
  buildMysqlConfig(config) {
    const server = config.server || {};
    const auth = config.auth || {};
    const options = config.options || {};

    const mysqlConfig = {
      host: server.host || 'localhost',
      port: server.port || 3306,
      database: server.database || 'mysql',
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
      enableKeepAlive: true,
      keepAliveInitialDelay: 0,
      multipleStatements: true  // Enable multiple result sets
    };

    // Authentication
    mysqlConfig.user = auth.username || 'root';
    mysqlConfig.password = auth.password || '';

    // SSL option
    if (options.ssl) {
      mysqlConfig.ssl = { rejectUnauthorized: false };
    }

    console.error('[DEBUG] MySQL config:', JSON.stringify(mysqlConfig, null, 2));
    return mysqlConfig;
  }

  /**
   * Establish connection pool
   */
  async connect() {
    if (this.isConnected && this.pool) {
      return; // Already connected
    }

    try {
      this.pool = mysql.createPool(this.mysqlConfig);

      // Test connection
      const connection = await this.pool.getConnection();
      connection.release();

      this.isConnected = true;
    } catch (err) {
      this.isConnected = false;
      throw new Error(`MySQL connection failed: ${err.message}`);
    }
  }

  /**
   * Close connection pool
   */
  async disconnect() {
    if (this.pool) {
      await this.pool.end();
      this.pool = null;
      this.isConnected = false;
    }
  }

  /**
   * Execute SQL query with structured result sets
   *
   * @param {string} query - SQL query to execute
   * @param {Object} options - Execution options
   * @returns {Promise<Object>} Structured result object
   */
  async execute(query, options = {}) {
    const startTime = Date.now();

    try {
      // Ensure connection
      if (!this.isConnected) {
        await this.connect();
      }

      // Execute query
      const [rows, fields] = await this.pool.query(query);

      const endTime = Date.now();
      const executionTime = endTime - startTime;

      // MySQL returns results differently based on query type
      // SELECT: array of row objects
      // INSERT/UPDATE/DELETE: ResultSetHeader object
      // Multiple statements: array of [rows, fields] pairs

      let resultSets = [];

      // Check if this is a multi-statement result
      if (Array.isArray(rows) && rows.length > 0 && Array.isArray(rows[0])) {
        // Multiple result sets
        for (let i = 0; i < rows.length; i++) {
          const rowSet = rows[i];
          const fieldSet = fields[i];

          if (Array.isArray(rowSet)) {
            // SELECT result
            resultSets.push(this.formatResultSet(rowSet, fieldSet));
          } else {
            // INSERT/UPDATE/DELETE result (ResultSetHeader)
            resultSets.push({
              columns: {},
              rows: [],
              rowCount: rowSet.affectedRows || 0
            });
          }
        }
      } else {
        // Single result set
        if (Array.isArray(rows)) {
          // SELECT result
          resultSets.push(this.formatResultSet(rows, fields));
        } else {
          // INSERT/UPDATE/DELETE result
          resultSets.push({
            columns: {},
            rows: [],
            rowCount: rows.affectedRows || 0
          });
        }
      }

      return {
        resultSets: resultSets,
        metadata: {
          executionTime: executionTime,
          rowsAffected: resultSets.map(rs => rs.rowCount)
        },
        error: null
      };

    } catch (err) {
      const endTime = Date.now();
      const executionTime = endTime - startTime;

      return {
        resultSets: [],
        metadata: {
          executionTime: executionTime,
          rowsAffected: []
        },
        error: {
          message: err.message || 'Unknown error',
          code: err.errno || err.code || null,
          lineNumber: null, // MySQL doesn't provide line numbers
          procName: null,
          sqlState: err.sqlState || null
        }
      };
    }
  }

  /**
   * Format a result set with column metadata
   */
  formatResultSet(rows, fields) {
    const columns = {};

    if (fields && fields.length > 0) {
      fields.forEach((field, index) => {
        columns[field.name] = {
          index: index,
          name: field.name,
          type: this.mapMySQLType(field.type),
          length: field.length,
          nullable: (field.flags & 1) === 0, // NOT_NULL flag is 1
          flags: field.flags,
          decimals: field.decimals
        };
      });
    }

    return {
      columns: columns,
      rows: rows || [],
      rowCount: rows ? rows.length : 0
    };
  }

  /**
   * Map MySQL data types to display strings
   */
  mapMySQLType(typeId) {
    // MySQL type constants
    const types = {
      0: 'decimal',
      1: 'tiny',
      2: 'short',
      3: 'long',
      4: 'float',
      5: 'double',
      6: 'null',
      7: 'timestamp',
      8: 'longlong',
      9: 'int24',
      10: 'date',
      11: 'time',
      12: 'datetime',
      13: 'year',
      15: 'varchar',
      16: 'bit',
      245: 'json',
      246: 'newdecimal',
      247: 'enum',
      248: 'set',
      249: 'tiny_blob',
      250: 'medium_blob',
      251: 'long_blob',
      252: 'blob',
      253: 'var_string',
      254: 'string',
      255: 'geometry'
    };

    return types[typeId] || 'unknown';
  }

  /**
   * Get metadata for database object (for IntelliSense)
   */
  async getMetadata(objectType, objectName, schemaName = null) {
    try {
      if (!this.isConnected) {
        await this.connect();
      }

      const database = schemaName || this.mysqlConfig.database;

      if (objectType === 'table' || objectType === 'view') {
        // Query information_schema for column metadata
        const query = `
          SELECT
            c.COLUMN_NAME as name,
            c.DATA_TYPE as type,
            c.CHARACTER_MAXIMUM_LENGTH as maxLength,
            c.NUMERIC_PRECISION as precision,
            c.NUMERIC_SCALE as scale,
            c.IS_NULLABLE as nullable,
            c.COLUMN_DEFAULT as defaultValue,
            c.COLUMN_KEY as columnKey,
            c.EXTRA as extra
          FROM INFORMATION_SCHEMA.COLUMNS c
          WHERE c.TABLE_SCHEMA = ?
            AND c.TABLE_NAME = ?
          ORDER BY c.ORDINAL_POSITION
        `;

        const [rows] = await this.pool.query(query, [database, objectName]);

        return {
          columns: rows.map(row => ({
            name: row.name,
            type: row.type,
            maxLength: row.maxLength,
            precision: row.precision,
            scale: row.scale,
            nullable: row.nullable === 'YES',
            defaultValue: row.defaultValue,
            isPrimaryKey: row.columnKey === 'PRI',
            isForeignKey: row.columnKey === 'MUL',
            isAutoIncrement: row.extra.includes('auto_increment')
          }))
        };
      }

      return { columns: [] };

    } catch (err) {
      throw new Error(`Failed to get metadata: ${err.message}`);
    }
  }

  /**
   * Get database type identifier
   * @returns {string}
   */
  getType() {
    return 'mysql';
  }
}

module.exports = MySQLDriver;
