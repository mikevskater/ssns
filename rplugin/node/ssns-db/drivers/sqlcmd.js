const { spawn } = require('child_process');
const BaseDriver = require('./base');

/**
 * SqlCmdDriver - SQL Server driver using sqlcmd command-line tool
 *
 * This matches vim-dadbod's approach and works reliably with Windows authentication
 * and named instances. Uses sqlcmd.exe which comes with SQL Server.
 */
class SqlCmdDriver extends BaseDriver {
  constructor(connectionString) {
    super(connectionString);
    this.config = this.parseConnectionString();
  }

  /**
   * Parse SQL Server connection string
   * @returns {Object} Configuration object
   */
  parseConnectionString() {
    const connStr = this.connectionString;

    // Remove sqlserver:// prefix
    const cleaned = connStr.replace(/^sqlserver:\/\//, '');

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

    // SQL Server accepts "." as localhost
    const server = serverWithInstance || 'localhost';

    return {
      server: server,
      database: database || 'master',
      auth: auth
    };
  }

  /**
   * Establish connection (test connectivity)
   */
  async connect() {
    try {
      // Test connection with a simple query
      await this.execute('SELECT 1');
      this.isConnected = true;
    } catch (err) {
      this.isConnected = false;
      throw err;
    }
  }

  /**
   * Close connection (no-op for sqlcmd)
   */
  async disconnect() {
    this.isConnected = false;
  }

  /**
   * Execute SQL query using sqlcmd
   *
   * @param {string} query - SQL query to execute
   * @param {Object} options - Execution options
   * @returns {Promise<Object>} Structured result object
   */
  async execute(query, options = {}) {
    const startTime = Date.now();

    return new Promise((resolve, reject) => {
      // Build sqlcmd arguments
      const args = [
        '-S', this.config.server,  // Server
        '-d', this.config.database, // Database
        '-W',  // Remove trailing spaces
        '-h', '-1',  // No headers
        '-s', '|',  // Column separator
        '-I',  // Enable quoted identifiers
      ];

      // Add authentication
      if (this.config.auth) {
        args.push('-U', this.config.auth.user);
        args.push('-P', this.config.auth.password);
      } else {
        args.push('-E');  // Use Windows authentication
      }

      // Add query via stdin
      args.push('-Q', query);

      console.error('[SQLCMD] Running:', 'sqlcmd', args.join(' ').replace(/-P\s+\S+/, '-P ***'));

      const sqlcmd = spawn('sqlcmd', args, {
        stdio: ['pipe', 'pipe', 'pipe'],
        shell: false
      });

      let stdout = '';
      let stderr = '';

      sqlcmd.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      sqlcmd.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      sqlcmd.on('close', (code) => {
        const endTime = Date.now();
        const executionTime = endTime - startTime;

        console.error('[SQLCMD] Exit code:', code);
        console.error('[SQLCMD] Stdout length:', stdout.length);
        console.error('[SQLCMD] Stderr:', stderr);

        if (code !== 0) {
          resolve({
            resultSets: [],
            metadata: {
              executionTime: executionTime,
              rowsAffected: []
            },
            error: {
              message: stderr || `sqlcmd exited with code ${code}`,
              code: code,
              lineNumber: null,
              procName: null
            }
          });
          return;
        }

        try {
          // Parse sqlcmd output
          const resultSets = this.parseSqlCmdOutput(stdout);

          resolve({
            resultSets: resultSets,
            metadata: {
              executionTime: executionTime,
              rowsAffected: resultSets.map(rs => rs.rowCount)
            },
            error: null
          });
        } catch (err) {
          resolve({
            resultSets: [],
            metadata: {
              executionTime: executionTime,
              rowsAffected: []
            },
            error: {
              message: err.message,
              code: null,
              lineNumber: null,
              procName: null
            }
          });
        }
      });

      sqlcmd.on('error', (err) => {
        const endTime = Date.now();
        const executionTime = endTime - startTime;

        resolve({
          resultSets: [],
          metadata: {
            executionTime: executionTime,
            rowsAffected: []
          },
          error: {
            message: `Failed to spawn sqlcmd: ${err.message}`,
            code: null,
            lineNumber: null,
            procName: null
          }
        });
      });
    });
  }

  /**
   * Parse sqlcmd output into result sets
   * @param {string} output - Raw sqlcmd output
   * @returns {Array} Array of result sets
   */
  parseSqlCmdOutput(output) {
    // Split output into lines
    const lines = output.split(/\r?\n/).filter(line => line.trim().length > 0);

    if (lines.length === 0) {
      return [];
    }

    // First line contains column names
    const headerLine = lines[0];
    const columnNames = headerLine.split('|').map(col => col.trim()).filter(col => col.length > 0);

    if (columnNames.length === 0) {
      return [];
    }

    // Build column metadata
    const columns = {};
    columnNames.forEach((name, index) => {
      columns[name] = {
        index: index,
        name: name,
        type: 'unknown',
        nullable: true
      };
    });

    // Parse data rows
    const rows = [];
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i];

      // Skip lines that are affected rows messages
      if (line.match(/^\(\d+ rows? affected\)/)) {
        continue;
      }

      const values = line.split('|').map(val => val.trim());

      if (values.length === columnNames.length) {
        const row = {};
        columnNames.forEach((name, index) => {
          let value = values[index];

          // Convert NULL strings to actual null
          if (value === 'NULL' || value === '') {
            value = null;
          }

          row[name] = value;
        });
        rows.push(row);
      }
    }

    return [{
      columns: columns,
      rows: rows,
      rowCount: rows.length
    }];
  }

  /**
   * Get metadata for database object
   * @param {string} objectType - 'table', 'view', 'procedure', 'function'
   * @param {string} objectName - Object name
   * @param {string} schemaName - Schema name (default: dbo)
   * @returns {Promise<Object>} Metadata object
   */
  async getMetadata(objectType, objectName, schemaName = 'dbo') {
    if (objectType === 'table' || objectType === 'view') {
      const query = `
        SELECT
          c.COLUMN_NAME as name,
          c.DATA_TYPE as type,
          c.CHARACTER_MAXIMUM_LENGTH as maxLength,
          c.NUMERIC_PRECISION as precision,
          c.NUMERIC_SCALE as scale,
          c.IS_NULLABLE as nullable
        FROM INFORMATION_SCHEMA.COLUMNS c
        WHERE c.TABLE_SCHEMA = '${schemaName}'
          AND c.TABLE_NAME = '${objectName}'
        ORDER BY c.ORDINAL_POSITION
      `;

      const result = await this.execute(query);

      if (result.error) {
        throw new Error(`Failed to get metadata: ${result.error.message}`);
      }

      return {
        columns: result.resultSets[0]?.rows || []
      };
    }

    return { columns: [] };
  }

  /**
   * Get database type identifier
   * @returns {string}
   */
  getType() {
    return 'sqlserver';
  }
}

module.exports = SqlCmdDriver;
