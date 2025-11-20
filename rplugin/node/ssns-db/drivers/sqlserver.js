const sql = require('mssql');
const msnodesqlv8 = require('msnodesqlv8'); // Use raw msnodesqlv8, not mssql wrapper
const BaseDriver = require('./base');

/**
 * SqlServerDriver - SQL Server database driver using mssql package
 *
 * Provides native SQL Server connectivity with:
 * - Connection pooling
 * - Multi-result set support (native)
 * - Structured errors with line numbers
 * - Rich column metadata (types, nullable, precision)
 */
class SqlServerDriver extends BaseDriver {
  constructor(connectionString) {
    super(connectionString);
    const parsed = this.parseConnectionString();
    this.config = parsed.config;
    this.useNativeDriver = parsed.useNativeDriver;
  }

  /**
   * Parse SQL Server connection string
   * Formats:
   *   sqlserver://server/database
   *   sqlserver://user:pass@server/database
   *   sqlserver://server\\INSTANCE/database
   *   sqlserver://user:pass@server\\INSTANCE/database
   *
   * @returns {Object} mssql configuration object
   */
  parseConnectionString() {
    const connStr = this.connectionString;

    console.error('[DEBUG] Original connection string:', connStr);

    // Extract query parameters (e.g., ?driver=...)
    let cleaned = connStr.replace(/^sqlserver:\/\//, '');
    let driverParam = null;

    const queryParamMatch = cleaned.match(/\?(.+)$/);
    if (queryParamMatch) {
      const params = new URLSearchParams(queryParamMatch[1]);
      driverParam = params.get('driver');
      if (driverParam) {
        // URL decode the driver name (URLSearchParams does this automatically)
        console.error('[DEBUG] Extracted driver parameter:', driverParam);
      }
      // Remove query params from connection string
      cleaned = cleaned.replace(/\?.*$/, '');
    }

    console.error('[DEBUG] After removing prefix and params:', cleaned);

    // Parse authentication (if present)
    let auth = null;
    let serverPart = cleaned;

    if (cleaned.includes('@')) {
      const parts = cleaned.split('@');
      const [user, password] = parts[0].split(':');
      auth = { user, password };
      serverPart = parts[1];
    }

    // Parse server and database
    const [serverWithInstance, database] = serverPart.split('/');
    console.error('[DEBUG] serverWithInstance:', serverWithInstance);
    console.error('[DEBUG] database:', database);

    // Parse server and instance (if present)
    // Handle both single backslash (\) and double backslash (\\)
    let server = serverWithInstance;
    let instanceName = null;
    if (serverWithInstance.includes('\\')) {
      const parts = serverWithInstance.split('\\');
      server = parts[0];
      instanceName = parts[1];
      console.error('[DEBUG] Parsed server:', server, 'instance:', instanceName);
    }

    // Replace "." with "localhost" for mssql config object
    if (server === '.') {
      server = 'localhost';
      console.error('[DEBUG] Replaced "." with "localhost"');
    } else {
      console.error('[DEBUG] Keeping server as:', server);
    }

    // Build mssql config
    const config = {
      server: server || 'localhost',
      database: database || 'master',
      options: {
        trustServerCertificate: true, // For development
        enableArithAbort: true,
        encrypt: false, // For local development
      },
      pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 30000
      }
    };

    // Add instance name if present
    if (instanceName) {
      config.options.instanceName = instanceName;
    }

    // Determine driver and authentication
    let useNativeDriver = false;

    if (auth) {
      // SQL Server authentication - use tedious (cross-platform)
      config.user = auth.user;
      config.password = auth.password;
      useNativeDriver = false;
    } else {
      // Windows authentication - use msnodesqlv8 (native ODBC)
      // Build connection string for msnodesqlv8
      const instancePart = instanceName ? `\\${instanceName}` : '';

      // Use driver from Lua if provided, otherwise use default
      const driver = driverParam || 'ODBC Driver 17 for SQL Server';

      const connectionString = `Driver={${driver}};Server=${server}${instancePart};Database=${database || 'master'};Trusted_Connection=yes;TrustServerCertificate=yes;`;

      console.error('[DEBUG] Using Windows auth with driver:', driver);
      console.error('[DEBUG] Connection string:', connectionString);

      return {
        config: {
          connectionString: connectionString,
          selectedDriver: driver
        },
        useNativeDriver: true
      };
    }

    console.error('[DEBUG] Using SQL auth with config:', JSON.stringify(config, null, 2));
    return {
      config: config,
      useNativeDriver: false
    };
  }

  /**
   * Establish connection pool
   */
  async connect() {
    if (this.isConnected && this.connection) {
      return; // Already connected
    }

    if (this.useNativeDriver) {
      // Use msnodesqlv8 for Windows authentication (callback-based API)
      console.error('[DEBUG] Connecting with msnodesqlv8 (Windows auth)');
      console.error('[DEBUG] Connection string:', this.config.connectionString);
      return new Promise((resolve, reject) => {
        msnodesqlv8.open(this.config.connectionString, (err, conn) => {
          if (err) {
            this.isConnected = false;
            console.error('[DEBUG] Connection error:', err);
            console.error('[DEBUG] Error details:', JSON.stringify(err, null, 2));
            reject(new Error(`SQL Server Windows Auth connection failed: ${err.message || err}\nConnection string: ${this.config.connectionString}`));
            return;
          }

          this.connection = conn;
          this.isConnected = true;
          console.error('[DEBUG] Successfully connected with msnodesqlv8');
          resolve();
        });
      });
    } else {
      // Use tedious for SQL Server authentication (promise-based API)
      console.error('[DEBUG] Connecting with tedious (SQL auth)');
      try {
        this.pool = await sql.connect(this.config);
        this.isConnected = true;
      } catch (err) {
        this.isConnected = false;
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
    const startTime = Date.now();

    try {
      // Ensure connection
      if (!this.isConnected) {
        await this.connect();
      }

      // Use different execution based on driver
      if (this.useNativeDriver) {
        return await this.executeWithMsnodesqlv8(query, startTime);
      } else {
        return await this.executeWithTedious(query, startTime);
      }

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

          // Build column metadata from meta array
          meta.forEach((colMeta, index) => {
            columns[colMeta.name] = {
              index: index,
              name: colMeta.name,
              type: this.mapSqlType(colMeta.sqlType) || 'unknown',
              nullable: colMeta.nullable !== false,
              size: colMeta.size
            };
          });

          // Convert rows from array of arrays to array of objects
          const rowObjects = results.rows.map(rowArray => {
            const rowObj = {};
            meta.forEach((colMeta, index) => {
              rowObj[colMeta.name] = rowArray[index];
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
          // Get column metadata from result set
          const columns = {};

          if (rs.columns) {
            Object.keys(rs.columns).forEach(colName => {
              const col = rs.columns[colName];
              columns[colName] = {
                index: col.index,
                name: col.name,
                length: col.length,
                type: this.mapSqlType(col.type),
                nullable: col.nullable !== false, // Default to nullable if not specified
                caseSensitive: col.caseSensitive,
                identity: col.identity || false,
                readOnly: col.readOnly || false
              };
            });
          }

          return {
            columns: columns,
            rows: rs || [],
            rowCount: rs ? rs.length : 0
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
    try {
      if (!this.isConnected) {
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

        const result = await this.pool.request().query(query);

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
    return 'sqlserver';
  }
}

module.exports = SqlServerDriver;
