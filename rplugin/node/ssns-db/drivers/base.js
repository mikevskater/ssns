/**
 * BaseDriver - Abstract base class for database drivers
 *
 * All database drivers (SQL Server, PostgreSQL, MySQL, SQLite) must extend this class
 * and implement the required methods.
 */
class BaseDriver {
  /**
   * @param {Object} config - Connection configuration object
   * @param {string} config.type - Database type
   * @param {Object} config.server - Server connection details
   * @param {Object} config.auth - Authentication details
   * @param {Object} [config.options] - Additional connection options
   */
  constructor(config) {
    this.config = config;
    this.pool = null;
    this.isConnected = false;
  }

  /**
   * Establish connection pool to the database
   * @returns {Promise<void>}
   * @throws {Error} Must be implemented by subclass
   */
  async connect() {
    throw new Error('BaseDriver.connect() must be implemented by subclass');
  }

  /**
   * Close connection pool
   * @returns {Promise<void>}
   * @throws {Error} Must be implemented by subclass
   */
  async disconnect() {
    throw new Error('BaseDriver.disconnect() must be implemented by subclass');
  }

  /**
   * Execute a SQL query and return structured results
   *
   * @param {string} query - SQL query to execute
   * @param {Object} options - Execution options
   * @returns {Promise<Object>} Result object with structure:
   * {
   *   resultSets: [
   *     {
   *       columns: { colName: { type, nullable, precision, scale }, ... },
   *       rows: [ { colName: value, ... }, ... ],
   *       rowCount: number
   *     }
   *   ],
   *   metadata: {
   *     executionTime: number (ms),
   *     rowsAffected: [number, ...]
   *   },
   *   error: null | {
   *     message: string,
   *     code: number,
   *     lineNumber: number,
   *     procName: string
   *   }
   * }
   * @throws {Error} Must be implemented by subclass
   */
  async execute(query, options = {}) {
    throw new Error('BaseDriver.execute() must be implemented by subclass');
  }

  /**
   * Get metadata for a database object (table, view, etc.)
   * Used for IntelliSense features
   *
   * @param {string} objectType - Type of object ('table', 'view', 'procedure', 'function')
   * @param {string} objectName - Name of the object
   * @param {string} schemaName - Schema name (optional)
   * @returns {Promise<Object>} Metadata object with structure:
   * {
   *   columns: [
   *     {
   *       name: string,
   *       type: string,
   *       nullable: boolean,
   *       defaultValue: string | null,
   *       isPrimaryKey: boolean,
   *       isForeignKey: boolean,
   *       foreignKeyTable: string | null,
   *       precision: number | null,
   *       scale: number | null
   *     }
   *   ],
   *   indexes: [ ... ],
   *   constraints: [ ... ]
   * }
   * @throws {Error} Must be implemented by subclass
   */
  async getMetadata(objectType, objectName, schemaName = null) {
    throw new Error('BaseDriver.getMetadata() must be implemented by subclass');
  }

  /**
   * Get the database type identifier
   * @returns {string} Database type ('sqlserver', 'postgres', 'mysql', 'sqlite')
   */
  getType() {
    throw new Error('BaseDriver.getType() must be implemented by subclass');
  }
}

module.exports = BaseDriver;
