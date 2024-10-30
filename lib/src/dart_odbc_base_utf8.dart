// ignore_for_file: lines_longer_than_80_chars

part of './dart_odbc_base.dart';

/// DartOdbc class
/// This is the base class that will be used to interact with the ODBC driver.
class DartOdbcUtf8 extends DartOdbc {
  /// DartOdbc constructor
  /// This constructor will initialize the ODBC environment and connection.
  /// The [pathToDriver] parameter is the path to the ODBC driver (optional).
  /// if [pathToDriver] is not provided, the driver will be auto-detected from the ODBC.ini file.
  /// The [dsn] parameter is the name of the DSN to connect to.
  /// If [dsn] is not provided, only [connectWithConnectionString] can be used.
  /// Optionally the ODBC version can be specified using the [version] parameter
  /// Definitions for these values can be found in the [LibOdbc] class.
  /// Please note that some drivers may not work with some drivers.
  DartOdbcUtf8({super.dsn, super.pathToDriver, super.version})
      : super._internal();

  @override
  void _initialize({int? version}) {
    final sqlOvOdbc = calloc.allocate<SQLULEN>(sizeOf<SQLULEN>())
      ..value = version ?? SQL_OV_ODBC3_80;
    final sqlNullHandle = calloc.allocate<Int>(sizeOf<Int>())
      ..value = SQL_NULL_HANDLE;
    final pHEnv = calloc.allocate<SQLHANDLE>(sizeOf<SQLHANDLE>());
    tryOdbc(
      _sql.SQLAllocEnv(
        // SQL_HANDLE_ENV,
        // Pointer.fromAddress(sqlNullHandle.address),
        pHEnv,
      ),
      operationType: SQL_HANDLE_ENV,
      handle: pHEnv.value,
      onException: HandleException(),
    );
    _hEnv = pHEnv.value;

    // if (version != null) {
    //   tryOdbc(
    //     _sql.SQLSetEnvAttr(
    //       _hEnv,
    //       SQL_ATTR_ODBC_VERSION,
    //       Pointer.fromAddress(sqlOvOdbc.address),
    //       0,
    //     ),
    //     handle: _hEnv,
    //     operationType: SQL_HANDLE_ENV,
    //     onException: EnvironmentAllocationException(),
    //   );
    // }
    calloc
      ..free(sqlOvOdbc)
      ..free(pHEnv)
      ..free(sqlNullHandle);
  }

  /// Connect to a database
  /// This is the name you gave when setting up the ODBC manager.
  /// The [username] parameter is the username to connect to the database.
  /// The [password] parameter is the password to connect to the database.
  @override
  Future<void> connect({
    required String username,
    required String password,
  }) async {
    if (_dsn == null) {
      throw ODBCException('DSN not provided');
    }
    final pHConn = calloc.allocate<SQLHDBC>(sizeOf<SQLHDBC>());
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_DBC, _hEnv, pHConn),
      handle: _hEnv,
      operationType: SQL_HANDLE_DBC,
      onException: HandleException(),
    );
    _hConn = pHConn.value;
    final cDsn = _dsn!.toNativeUtf8().cast<SQLCHAR>();
    final cUsername = username.toNativeUtf8().cast<SQLCHAR>();
    final cPassword = password.toNativeUtf8().cast<SQLCHAR>();
    tryOdbc(
      _sql.SQLConnect(
        _hConn,
        cDsn,
        _dsn!.length,
        cUsername,
        username.length,
        cPassword,
        password.length,
      ),
      handle: _hConn,
      operationType: SQL_HANDLE_DBC,
      onException: ConnectionException(),
    );
    calloc
      ..free(pHConn)
      ..free(cDsn)
      ..free(cUsername)
      ..free(cPassword);
  }

  /// Connects to the database using a connection string instead of a DSN.
  ///
  /// [connectionString] is the full connection string that provides all necessary
  /// connection details like driver, server, database, etc.
  ///
  /// This method is useful for connecting to data sources like Excel files or text files
  /// without having to define a DSN.
  ///
  /// Throws a [ConnectionException] if the connection fails.
  @override
  Future<void> connectWithConnectionString(String connectionString) async {
    final pHConn = calloc.allocate<SQLHDBC>(sizeOf<SQLHDBC>());
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_DBC, _hEnv, pHConn),
      handle: _hEnv,
      operationType: SQL_HANDLE_DBC,
      onException: HandleException(),
    );
    _hConn = pHConn.value;

    final cConnectionString = connectionString.toNativeUtf8().cast<SQLCHAR>();

    final outConnectionString =
        calloc.allocate<SQLCHAR>(1024); // Adjust size as necessary
    final outConnectionStringLen = calloc.allocate<Short>(sizeOf<Short>());

    tryOdbc(
      _sql.SQLDriverConnect(
        _hConn,
        nullptr,
        cConnectionString,
        SQL_NTS,
        outConnectionString,
        1024,
        outConnectionStringLen,
        SQL_DRIVER_NOPROMPT,
      ),
      handle: _hConn,
      operationType: SQL_HANDLE_DBC,
      onException: ConnectionException(),
    );
    calloc
      ..free(pHConn)
      ..free(cConnectionString)
      ..free(outConnectionString)
      ..free(outConnectionStringLen);
  }

  /// Retrieves a list of tables from the connected database.
  ///
  /// Optionally, you can filter the results by specifying [tableName], [catalog],
  /// [schema], or [tableType]. If these are omitted, all tables will be returned.
  ///
  /// Returns a list of maps, where each map represents a table with its name,
  /// catalog, schema, and type.
  ///
  /// Throws a [FetchException] if fetching tables fails.
  @override
  Future<List<Map<String, dynamic>>> getTables({
    String? tableName,
    String? catalog,
    String? schema,
    String? tableType,
  }) async {
    final pHStmt = calloc.allocate<SQLHSTMT>(sizeOf<SQLHSTMT>());
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_STMT, _hConn, pHStmt),
      handle: _hConn,
      onException: HandleException(),
    );
    final hStmt = pHStmt.value;

    final cCatalog = catalog?.toNativeUtf8().cast<SQLCHAR>() ?? nullptr;
    final cSchema = schema?.toNativeUtf8().cast<SQLCHAR>() ?? nullptr;
    final cTableName = tableName?.toNativeUtf8().cast<SQLCHAR>() ?? nullptr;
    final cTableType = tableType?.toNativeUtf8().cast<SQLCHAR>() ?? nullptr;

    tryOdbc(
      _sql.SQLTables(
        hStmt,
        cCatalog,
        SQL_NTS,
        cSchema,
        SQL_NTS,
        cTableName,
        SQL_NTS,
        cTableType,
        SQL_NTS,
      ),
      handle: hStmt,
      onException: FetchException(),
    );

    final result = _getResult(hStmt, {});

    // Clean up
    _sql.SQLFreeHandle(SQL_HANDLE_STMT, hStmt);
    calloc
      ..free(pHStmt)
      ..free(cCatalog)
      ..free(cSchema)
      ..free(cTableName)
      ..free(cTableType);

    return result;
  }

  /// Execute a query
  /// The [query] parameter is the SQL query to execute.
  /// This function will return a list of maps where each map represents a row
  /// in the result set. The keys in the map are the column names and the values
  /// are the column values.
  /// The [params] parameter is a list of parameters to bind to the query.
  /// Example query:
  /// ```dart
  /// final List<Map<String, dynamic>> result = odbc.execute(
  ///   'SELECT * FROM USERS WHERE UID = ?',
  ///   params: [1],
  /// );
  /// ```
  @override
  Future<List<Map<String, dynamic>>> execute(
    String query, {
    List<dynamic>? params,
    Map<String, ColumnType> columnConfig = const {},
  }) async {
    final pHStmt = calloc.allocate<SQLHSTMT>(sizeOf<SQLHSTMT>());
    tryOdbc(
      _sql.SQLAllocHandle(SQL_HANDLE_STMT, _hConn, pHStmt),
      handle: _hConn,
      onException: HandleException(),
    );
    final hStmt = pHStmt.value;
    final pointers = <OdbcPointer<dynamic>>[];
    final cQuery = query.toNativeUtf8();

    // binding sanitized params
    if (params != null) {
      tryOdbc(
        _sql.SQLPrepare(hStmt, cQuery.cast(), cQuery.length),
        handle: hStmt,
        onException: QueryException(),
      );

      for (var i = 0; i < params.length; i++) {
        final param = params[i];
        final cParam = OdbcConversions.toPointer(param);
        tryOdbc(
          _sql.SQLBindParameter(
            hStmt,
            i + 1,
            SQL_PARAM_INPUT,
            OdbcConversions.getCtypeFromType(param.runtimeType),
            OdbcConversions.getSqlTypeFromType(param.runtimeType),
            0,
            0,
            cParam.ptr,
            cParam.length,
            nullptr,
          ),
          handle: hStmt,
        );
      }
    }

    if (params == null) {
      tryOdbc(
        _sql.SQLExecDirect(hStmt, cQuery.cast(), query.length),
        handle: hStmt,
      );
    } else {
      tryOdbc(_sql.SQLExecute(hStmt), handle: hStmt);
    }

    final result = _getResult(hStmt, columnConfig);

    // free memory
    for (final ptr in pointers) {
      ptr.free();
    }
    calloc.free(cQuery);

    return result;
  }

  /// Function to disconnect from the database
  @override
  Future<void> disconnect() async {
    _sql
      ..SQLDisconnect(_hConn)
      ..SQLFreeHandle(SQL_HANDLE_DBC, _hConn)
      ..SQLFreeHandle(SQL_HANDLE_ENV, _hEnv);
    _hConn = nullptr;
    _hEnv = nullptr;
  }

  /// Function to handle ODBC errors
  /// The [status] parameter is the status code returned by the ODBC function.
  /// The [onException] parameter is the exception to throw if the status code
  /// is an error.
  /// The [handle] parameter is the handle to the ODBC object that caused the
  /// error.
  /// The [operationType] parameter is the type of operation that caused the
  /// error.
  /// If [handle] is not provided, the error message will not be descriptive.
  @override
  void tryOdbc(
    int status, {
    SQLHANDLE? handle,
    int operationType = SQL_HANDLE_STMT,
    ODBCException? onException,
  }) {
    onException ??= ODBCException('ODBC error');
    onException.code = status;
    if (status == SQL_ERROR) {
      if (handle != null) {
        final nativeErr = calloc.allocate<Int>(sizeOf<Int>())..value = status;
        final message = '1' * 10000;
        final msg = message.toNativeUtf8();
        final pStatus = calloc.allocate<SQLCHAR>(sizeOf<SQLCHAR>())
          ..value = status;
        try {
          _sql.SQLGetDiagRec(
            operationType,
            handle,
            1,
            pStatus,
            nativeErr,
            msg.cast(),
            message.length,
            nullptr,
          );
        } catch (e) {
          // ignore
        }

        onException.message = msg.toDartString();

        // free memory
        calloc
          ..free(nativeErr)
          ..free(msg)
          ..free(pStatus);
      }

      throw onException;
    }
  }

  @override
  List<Map<String, dynamic>> _getResult(
    SQLHSTMT hStmt,
    Map<String, ColumnType> columnConfig,
  ) {
    final columnCount = calloc.allocate<SQLSMALLINT>(sizeOf<SQLSMALLINT>());
    tryOdbc(
      _sql.SQLNumResultCols(hStmt, columnCount),
      handle: hStmt,
      onException: FetchException(),
    );

    final columnNames = <String>[];
    for (var i = 1; i <= columnCount.value; i++) {
      final columnNameLength =
          calloc.allocate<SQLSMALLINT>(sizeOf<SQLSMALLINT>());
      final columnName = calloc.allocate<Uint16>(sizeOf<Uint16>() * 256);
      tryOdbc(
        _sql.SQLDescribeCol(
          hStmt,
          i,
          columnName.cast(),
          256,
          columnNameLength,
          nullptr,
          nullptr,
          nullptr,
          nullptr,
        ),
        handle: hStmt,
        onException: FetchException(),
      );
      final charCodes = columnName.asTypedList(columnNameLength.value).toList()
        ..removeWhere((e) => e == 0);
      columnNames.add(
        String.fromCharCodes(charCodes),
      );

      // free memory
      calloc
        ..free(columnName)
        ..free(columnNameLength);
    }

    final rows = <Map<String, dynamic>>[];

    while (_sql.SQLFetch(hStmt) == SQL_SUCCESS) {
      final row = <String, dynamic>{};
      for (var i = 1; i <= columnCount.value; i++) {
        final columnType = columnConfig[columnNames[i - 1]];
        final columnValueLength = calloc.allocate<SQLLEN>(sizeOf<SQLLEN>());
        final columnValue = calloc.allocate<Uint16>(
          sizeOf<Uint16>() * (columnType?.size ?? 256),
        );
        tryOdbc(
          _sql.SQLGetData(
            hStmt,
            i,
            /* columnType?.type ?? */ SQL_WCHAR,
            columnValue.cast(),
            columnType?.size ?? 256,
            columnValueLength,
          ),
          handle: hStmt,
          onException: FetchException(),
        );
        if (columnValueLength.value == SQL_NULL_DATA) {
          row[columnNames[i - 1]] = null;
          continue;
        }
        // removing trailing zeros before converting to string
        final charCodes = columnValue
            .asTypedList(columnValueLength.value)
            .toList()
          ..removeWhere((e) => e == 0);
        row[columnNames[i - 1]] = String.fromCharCodes(charCodes);

        // free memory
        calloc
          ..free(columnValue)
          ..free(columnValueLength);
      }

      rows.add(row);
    }

    // free memory
    _sql.SQLFreeHandle(SQL_HANDLE_STMT, hStmt);
    calloc.free(columnCount);

    return rows;
  }

  /// On some platforms with some drivers, the ODBC driver may return
  /// whitespace characters as unicode characters. This function will remove
  /// these unicode whitespace characters from the result set.
  @Deprecated('This method is no longer needed')
  static List<Map<String, dynamic>> removeWhitespaceUnicodes(
    List<Map<String, dynamic>> result,
  ) {
    return result.map((record) {
      final sanitizedDict = <String, String>{};
      record.forEach((key, value) {
        // Trim all whitespace from keys and values using a regular expression
        final sanitizedKey = key.replaceAll(RegExp(r'\s+'), '');
        final cleanedKey = sanitizedKey.removeUnicodeWhitespaces();
        final sanitizedValue =
            value.toString().replaceAll(RegExp(r'[\s\u00A0]+'), '');
        final cleanedValue = sanitizedValue.removeUnicodeWhitespaces();

        sanitizedDict[cleanedKey] = cleanedValue;
      });
      return sanitizedDict;
    }).toList();
  }
}