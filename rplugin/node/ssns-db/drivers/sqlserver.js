const sql = require('mssql');
const msnodesqlv8 = require('msnodesqlv8'); // Use raw msnodesqlv8, not mssql wrapper
const BaseDriver = require('./base');
const { ssnsLog } = require('../ssns-log');

/**
 * SqlServerDriver - SQL Server database driver using mssql package
 *
 * Provides native SQL Server connectivity with:
 * - Connection pooling
 * - Multi-result set support (native)
 * - Structured errors with line numbers
 * - Rich column metadata (types, nullable, precision)
 *
 * Authentication modes:
 * - Windows: Uses msnodesqlv8 with ODBC driver
 * - SQL: Uses mssql/tedious with username/password
 */
class SqlServerDriver extends BaseDriver {
  /**
   * @param {Object} config - Connection configuration object
   * @param {string} config.type - "sqlserver"
   * @param {Object} config.server - Server details
   * @param {string} config.server.host - Server hostname or IP
   * @param {string} [config.server.instance] - Named instance
   * @param {number} [config.server.port] - Port number (default: 1433)
   * @param {string} [config.server.database] - Database name (default: master)
   * @param {Object} config.auth - Authentication details
   * @param {string} config.auth.type - "windows" or "sql"
   * @param {string} [config.auth.username] - SQL auth username
   * @param {string} [config.auth.password] - SQL auth password
   * @param {Object} [config.options] - Additional options
   * @param {string} [config.options.odbc_driver] - ODBC driver name
   * @param {boolean} [config.options.trust_server_certificate] - Trust cert (default: true)
   */
  constructor(config) {
    super(config);
    this.useNativeDriver = config.auth && config.auth.type === 'windows';
    this.odbcConnectionString = null;
    this.tediousConfig = null;

    if (this.useNativeDriver) {
      this.odbcConnectionString = this.buildOdbcConnectionString(config);
    } else {
      this.tediousConfig = this.buildTediousConfig(config);
    }
  }

  /**
   * Escape a value for use in ODBC connection string
   * ODBC values containing special chars must be wrapped in braces
   *
   * @param {string} value - Value to escape
   * @returns {string} Escaped value
   */
  escapeOdbcValue(value) {
    if (!value) return '';

    // Check if value contains special characters that need escaping
    if (value.includes(';') || value.includes('=') || value.includes('{') || value.includes('}')) {
      // Escape braces by doubling them, then wrap in braces
      const escaped = value.replace(/\}/g, '}}');
      return `{${escaped}}`;
    }

    return value;
  }

  /**
   * Build ODBC connection string from config for Windows Authentication
   *
   * @param {Object} config - Connection configuration
   * @returns {string} ODBC connection string
   */
  buildOdbcConnectionString(config) {
    const server = config.server || {};
    const options = config.options || {};

    // Get ODBC driver (default to ODBC Driver 17)
    const driver = options.odbc_driver || 'ODBC Driver 17 for SQL Server';

    // Build server string with optional instance
    let serverStr = server.host || 'localhost';

    // Replace "." with "localhost" for ODBC
    if (serverStr === '.') {
      serverStr = 'localhost';
    }

    // Add instance name if present
    if (server.instance) {
      serverStr += '\\' + server.instance;
    }

    // Build connection string parts
    const parts = [];

    // Driver (always wrapped in braces for ODBC)
    parts.push(`Driver={${driver}}`);

    // Server
    parts.push(`Server=${this.escapeOdbcValue(serverStr)}`);

    // Database
    const database = server.database || 'master';
    parts.push(`Database=${this.escapeOdbcValue(database)}`);

    // Windows Authentication
    parts.push('Trusted_Connection=yes');

    // Trust server certificate (default: true for dev)
    const trustCert = options.trust_server_certificate !== false;
    if (trustCert) {
      parts.push('TrustServerCertificate=yes');
    }

    const connectionString = parts.join(';') + ';';

    ssnsLog(`[sqlserver] Built ODBC connection string: ${connectionString}`);
    return connectionString;
  }

  /**
   * Build tedious/mssql config from connection config for SQL Authentication
   *
   * @param {Object} config - Connection configuration
   * @returns {Object} mssql config object
   */
  buildTediousConfig(config) {
    const server = config.server || {};
    const auth = config.auth || {};
    const options = config.options || {};

    // Build server hostname
    let host = server.host || 'localhost';
    if (host === '.') {
      host = 'localhost';
    }

    const tediousConfig = {
      server: host,
      database: server.database || 'master',
      user: auth.username || '',
      password: auth.password || '',
      options: {
        trustServerCertificate: options.trust_server_certificate !== false,
        enableArithAbort: true,
        encrypt: options.ssl === true,
      },
      pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 30000
      }
    };

    // Add instance name if present (for tedious, it goes in options)
    if (server.instance) {
      tediousConfig.options.instanceName = server.instance;
    }

    // Add port if specified (only for non-named instances)
    if (server.port && !server.instance) {
      tediousConfig.port = server.port;
    }

    ssnsLog(`[sqlserver] Built tedious config: ${JSON.stringify(tediousConfig, null, 2)}`);
    return tediousConfig;
  }

  /**
   * Establish connection pool
   */
  async connect() {
    ssnsLog('[sqlserver] connect() called');
    if (this.isConnected && this.connection) {
      ssnsLog('[sqlserver] Already connected');
      return; // Already connected
    }

    if (this.useNativeDriver) {
      // Use msnodesqlv8 for Windows authentication (callback-based API)
      ssnsLog('[sqlserver] Connecting with msnodesqlv8 (Windows auth)');
      ssnsLog(`[sqlserver] Connection string: ${this.odbcConnectionString}`);
      return new Promise((resolve, reject) => {
        msnodesqlv8.open(this.odbcConnectionString, (err, conn) => {
          if (err) {
            this.isConnected = false;
            ssnsLog(`[sqlserver] Connection error: ${err}`);
            ssnsLog(`[sqlserver] Error details: ${JSON.stringify(err, null, 2)}`);
            reject(new Error(`SQL Server Windows Auth connection failed: ${err.message || err}\nConnection string: ${this.odbcConnectionString}`));
            return;
          }

          this.connection = conn;
          this.isConnected = true;
          ssnsLog('[sqlserver] Successfully connected with msnodesqlv8');
          resolve();
        });
      });
    } else {
      // Use tedious for SQL Server authentication (promise-based API)
      ssnsLog('[sqlserver] Connecting with tedious (SQL auth)');
      try {
        this.pool = await sql.connect(this.tediousConfig);
        this.isConnected = true;
        ssnsLog('[sqlserver] Successfully connected with tedious');
      } catch (err) {
        this.isConnected = false;
        ssnsLog(`[sqlserver] Connection failed: ${err.message}`);
        throw new Error(`SQL Server connection failed: ${err.message}`);
      }
    }
  }

  /**
   * Close connection pool
   */
  async disconnect() {
    if (this.useNativeDriver && this.connection) {
      // Close msnodesqlv8 connection
      this.connection.close(() => {
        this.connection = null;
        this.isConnected = false;
      });
    } else if (this.pool) {
      // Close tedious pool
      await this.pool.close();
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
    ssnsLog(`[sqlserver] execute() called with query: ${query}`);
    const startTime = Date.now();

    try {
      // Ensure connection
      if (!this.isConnected) {
        ssnsLog('[sqlserver] Not connected, calling connect()');
        await this.connect();
      }

      // Use different execution based on driver
      if (this.useNativeDriver) {
        ssnsLog('[sqlserver] Using msnodesqlv8 for execution');
        return await this.executeWithMsnodesqlv8(query, startTime);
      } else {
        ssnsLog('[sqlserver] Using tedious for execution');
        return await this.executeWithTedious(query, startTime);
      }

    } catch (err) {
      const endTime = Date.now();
      const executionTime = endTime - startTime;
      ssnsLog(`[sqlserver] execute() error: ${err && err.stack ? err.stack : err}`);
      return {
        resultSets: [],
        metadata: {
          executionTime: executionTime,
          rowsAffected: []
        },
        error: {
          message: err.message || 'Unknown error',
          code: err.number || err.code || null,
          lineNumber: err.lineNumber || null,
          procName: err.procName || null,
          state: err.state || null,
          class: err.class || null
        }
      };
    }
  }

  /**
   * Execute query using msnodesqlv8 (Windows auth)
   *
   * Uses queryRaw to handle multiple result sets properly.
   * The callback is invoked once per result set, with 'more' parameter
   * indicating if there are additional result sets.
   */
  async executeWithMsnodesqlv8(query, startTime) {
    return new Promise((resolve) => {
      const allResultSets = [];
      let hasError = false;
      let errorInfo = null;

      // Use queryRaw for multi-result set support
      this.connection.queryRaw(query, (err, results, more) => {
        // Check for errors
        if (err) {
          hasError = true;
          errorInfo = err;

          // If error, don't wait for more results - resolve immediately
          if (!more) {
            const endTime = Date.now();
            const executionTime = endTime - startTime;

            resolve({
              resultSets: [],
              metadata: {
                executionTime: executionTime,
                rowsAffected: []
              },
              error: {
                message: err.message || 'Unknown error',
                code: err.code || null,
                lineNumber: err.lineNumber || null,
                procName: err.procName || null,
                state: err.state || null,
                class: err.class || null
              }
            });
          }
          return;
        }

        // Process this result set
        if (results && results.rows) {
          // queryRaw returns { meta, rows }
          // meta contains column metadata
          // rows is array of arrays (not objects!)

          const columns = {};
          const meta = results.meta || [];

          // Generate unique column keys to handle duplicate/empty column names
          const columnKeys = [];
          const seenNames = {};
          meta.forEach((colMeta) => {
            const baseName = colMeta.name || '(No column name)';
            if (seenNames[baseName] === undefined) {
              seenNames[baseName] = 0;
              columnKeys.push(baseName);
            } else {
              seenNames[baseName]++;
              columnKeys.push(`${baseName}_${seenNames[baseName]}`);
            }
          });

          // Build column metadata from meta array using unique keys
          meta.forEach((colMeta, index) => {
            const key = columnKeys[index];
            columns[key] = {
              index: index,
              name: colMeta.name || '(No column name)',
              type: this.mapSqlType(colMeta.sqlType) || 'unknown',
              nullable: colMeta.nullable !== false,
              size: colMeta.size
            };
          });

          // Convert rows from array of arrays to array of objects
          // Also convert Date objects to ISO strings for JSON serialization
          const rowObjects = results.rows.map(rowArray => {
            const rowObj = {};
            meta.forEach((colMeta, index) => {
              const value = rowArray[index];
              const key = columnKeys[index];
              // Convert Date to SQL Server format (YYYY-MM-DD HH:mm:ss.SSS) for display
              rowObj[key] = value instanceof Date
                ? value.toISOString().replace('T', ' ').slice(0, -1)
                : value;
            });
            return rowObj;
          });

          allResultSets.push({
            columns: columns,
            rows: rowObjects,
            rowCount: rowObjects.length
          });
        }

        // Check if this is the last result set
        if (!more) {
          const endTime = Date.now();
          const executionTime = endTime - startTime;

          resolve({
            resultSets: allResultSets,
            metadata: {
              executionTime: executionTime,
              rowsAffected: allResultSets.map(rs => rs.rowCount)
            },
            error: null
          });
        }
      });
    });
  }

  /**
   * Execute query using tedious (SQL auth)
   */
  async executeWithTedious(query, startTime) {
    try {
      // Execute query
      const result = await this.pool.request().query(query);

      const endTime = Date.now();
      const executionTime = endTime - startTime;

      // Handle multiple result sets (native support!)
      const resultSets = Array.isArray(result.recordsets)
        ? result.recordsets
        : [result.recordset];

      // Format result sets with column metadata
      const formattedResultSets = resultSets
        .filter(rs => rs !== undefined) // Filter out undefined result sets
        .map(rs => {
          // Get column metadata from result set, sorted by index
          const columns = {};
          const columnKeys = [];
          const seenNames = {};

          if (rs.columns) {
            // Sort columns by index to ensure correct order
            const sortedCols = Object.values(rs.columns).sort((a, b) => a.index - b.index);

            // Generate unique column keys to handle duplicate/empty column names
            sortedCols.forEach((col) => {
              const baseName = col.name || '(No column name)';
              if (seenNames[baseName] === undefined) {
                seenNames[baseName] = 0;
                columnKeys.push(baseName);
              } else {
                seenNames[baseName]++;
                columnKeys.push(`${baseName}_${seenNames[baseName]}`);
              }
            });

            // Build column metadata using unique keys
            sortedCols.forEach((col, index) => {
              const key = columnKeys[index];
              columns[key] = {
                index: col.index,
                name: col.name || '(No column name)',
                length: col.length,
                type: this.mapSqlType(col.type),
                nullable: col.nullable !== false,
                caseSensitive: col.caseSensitive,
                identity: col.identity || false,
                readOnly: col.readOnly || false
              };
            });
          }

          // Convert rows to plain objects with Date → string conversion for JSON serialization
          // Use columnKeys to map values correctly for duplicate column names
          const rowObjects = (rs || []).map(row => {
            const rowObj = {};
            if (columnKeys.length > 0) {
              // Use column keys for proper ordering
              columnKeys.forEach((key, index) => {
                const originalName = columns[key].name;
                const value = row[originalName];
                // Convert Date to SQL Server format (YYYY-MM-DD HH:mm:ss.SSS) for display
                rowObj[key] = value instanceof Date
                  ? value.toISOString().replace('T', ' ').slice(0, -1)
                  : value;
              });
            } else {
              // Fallback for when we don't have column metadata
              for (const colName in row) {
                const value = row[colName];
                // Convert Date to SQL Server format (YYYY-MM-DD HH:mm:ss.SSS) for display
                rowObj[colName] = value instanceof Date
                  ? value.toISOString().replace('T', ' ').slice(0, -1)
                  : value;
              }
            }
            return rowObj;
          });

          return {
            columns: columns,
            rows: rowObjects,
            rowCount: rowObjects.length
          };
        });

      return {
        resultSets: formattedResultSets,
        metadata: {
          executionTime: executionTime,
          rowsAffected: result.rowsAffected || []
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
          code: err.number || err.code || null,
          lineNumber: err.lineNumber || null,
          procName: err.procName || null,
          state: err.state || null,
          class: err.class || null
        }
      };
    }
  }

  /**
   * Map SQL Server data types to display strings
   * @param {Object} sqlType - mssql type object
   * @returns {string} Human-readable type name
   */
  mapSqlType(sqlType) {
    if (!sqlType) return 'unknown';

    const typeMap = {
      [sql.BigInt]: 'bigint',
      [sql.Binary]: 'binary',
      [sql.Bit]: 'bit',
      [sql.Char]: 'char',
      [sql.Date]: 'date',
      [sql.DateTime]: 'datetime',
      [sql.DateTime2]: 'datetime2',
      [sql.DateTimeOffset]: 'datetimeoffset',
      [sql.Decimal]: 'decimal',
      [sql.Float]: 'float',
      [sql.Int]: 'int',
      [sql.Money]: 'money',
      [sql.NChar]: 'nchar',
      [sql.NText]: 'ntext',
      [sql.Numeric]: 'numeric',
      [sql.NVarChar]: 'nvarchar',
      [sql.Real]: 'real',
      [sql.SmallDateTime]: 'smalldatetime',
      [sql.SmallInt]: 'smallint',
      [sql.SmallMoney]: 'smallmoney',
      [sql.Text]: 'text',
      [sql.Time]: 'time',
      [sql.TinyInt]: 'tinyint',
      [sql.UniqueIdentifier]: 'uniqueidentifier',
      [sql.VarBinary]: 'varbinary',
      [sql.VarChar]: 'varchar',
      [sql.Xml]: 'xml'
    };

    return typeMap[sqlType] || sqlType.toString();
  }

  /**
   * Get metadata for database object (for IntelliSense)
   *
   * @param {string} objectType - 'table', 'view', 'procedure', 'function'
   * @param {string} objectName - Object name
   * @param {string} schemaName - Schema name (default: dbo)
   * @returns {Promise<Object>} Rich metadata object
   */
  async getMetadata(objectType, objectName, schemaName = 'dbo') {
    ssnsLog(`[sqlserver] getMetadata() called with objectType: ${objectType}, objectName: ${objectName}, schemaName: ${schemaName}`);
    try {
      if (!this.isConnected) {
        ssnsLog('[sqlserver] Not connected, calling connect() in getMetadata');
        await this.connect();
      }

      if (objectType === 'table' || objectType === 'view') {
        // Query system catalogs for column metadata
        const query = `
          SELECT
            c.COLUMN_NAME as name,
            c.DATA_TYPE as type,
            c.CHARACTER_MAXIMUM_LENGTH as maxLength,
            c.NUMERIC_PRECISION as precision,
            c.NUMERIC_SCALE as scale,
            c.IS_NULLABLE as nullable,
            c.COLUMN_DEFAULT as defaultValue,
            CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END as isPrimaryKey,
            CASE WHEN fk.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END as isForeignKey,
            fk.FK_TABLE as foreignKeyTable,
            fk.FK_SCHEMA as foreignKeySchema
          FROM INFORMATION_SCHEMA.COLUMNS c
          LEFT JOIN (
            SELECT ku.TABLE_SCHEMA, ku.TABLE_NAME, ku.COLUMN_NAME
            FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
            JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku
              ON tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
              AND tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
              AND tc.TABLE_SCHEMA = ku.TABLE_SCHEMA
              AND tc.TABLE_NAME = ku.TABLE_NAME
          ) pk ON c.TABLE_SCHEMA = pk.TABLE_SCHEMA
             AND c.TABLE_NAME = pk.TABLE_NAME
             AND c.COLUMN_NAME = pk.COLUMN_NAME
          LEFT JOIN (
            SELECT
              ku.TABLE_SCHEMA,
              ku.TABLE_NAME,
              ku.COLUMN_NAME,
              cu.TABLE_NAME as FK_TABLE,
              cu.TABLE_SCHEMA as FK_SCHEMA
            FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS rc
            JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku
              ON rc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
              AND rc.CONSTRAINT_SCHEMA = ku.CONSTRAINT_SCHEMA
            JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE cu
              ON rc.UNIQUE_CONSTRAINT_NAME = cu.CONSTRAINT_NAME
              AND rc.UNIQUE_CONSTRAINT_SCHEMA = cu.CONSTRAINT_SCHEMA
          ) fk ON c.TABLE_SCHEMA = fk.TABLE_SCHEMA
             AND c.TABLE_NAME = fk.TABLE_NAME
             AND c.COLUMN_NAME = fk.COLUMN_NAME
          WHERE c.TABLE_SCHEMA = '${schemaName}'
            AND c.TABLE_NAME = '${objectName}'
          ORDER BY c.ORDINAL_POSITION
        `;

        ssnsLog(`[sqlserver] getMetadata() running query: ${query}`);
        const result = await this.pool.request().query(query);
        ssnsLog(`[sqlserver] getMetadata() query result: ${JSON.stringify(result.recordset)}`);

        return {
          columns: result.recordset.map(row => ({
            name: row.name,
            type: row.type,
            maxLength: row.maxLength,
            precision: row.precision,
            scale: row.scale,
            nullable: row.nullable === 'YES',
            defaultValue: row.defaultValue,
            isPrimaryKey: row.isPrimaryKey === 1,
            isForeignKey: row.isForeignKey === 1,
            foreignKeyTable: row.foreignKeyTable,
            foreignKeySchema: row.foreignKeySchema
          }))
        };
      }

      ssnsLog('[sqlserver] getMetadata() objectType not table/view, returning empty columns');
      return { columns: [] };

    } catch (err) {
      ssnsLog(`[sqlserver] getMetadata() error: ${err && err.stack ? err.stack : err}`);
      throw new Error(`Failed to get metadata: ${err.message}`);
    }
  }

  /**
   * Get database type identifier
   * @returns {string}
   */
  getType() {
    return 'sqlserver';
  }
}

module.exports = SqlServerDriver;
