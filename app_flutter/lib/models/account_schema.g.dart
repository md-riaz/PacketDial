// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_schema.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAccountSchemaCollection on Isar {
  IsarCollection<AccountSchema> get accountSchemas => this.collection();
}

const AccountSchemaSchema = CollectionSchema(
  name: r'AccountSchema',
  id: -7481566314752538133,
  properties: {
    r'accountId': PropertySchema(
      id: 0,
      name: r'accountId',
      type: IsarType.string,
    ),
    r'autoRegister': PropertySchema(
      id: 1,
      name: r'autoRegister',
      type: IsarType.bool,
    ),
    r'displayName': PropertySchema(
      id: 2,
      name: r'displayName',
      type: IsarType.string,
    ),
    r'password': PropertySchema(
      id: 3,
      name: r'password',
      type: IsarType.string,
    ),
    r'server': PropertySchema(
      id: 4,
      name: r'server',
      type: IsarType.string,
    ),
    r'srtpEnabled': PropertySchema(
      id: 5,
      name: r'srtpEnabled',
      type: IsarType.bool,
    ),
    r'stunServer': PropertySchema(
      id: 6,
      name: r'stunServer',
      type: IsarType.string,
    ),
    r'tlsEnabled': PropertySchema(
      id: 7,
      name: r'tlsEnabled',
      type: IsarType.bool,
    ),
    r'transport': PropertySchema(
      id: 8,
      name: r'transport',
      type: IsarType.string,
    ),
    r'turnServer': PropertySchema(
      id: 9,
      name: r'turnServer',
      type: IsarType.string,
    ),
    r'username': PropertySchema(
      id: 10,
      name: r'username',
      type: IsarType.string,
    )
  },
  estimateSize: _accountSchemaEstimateSize,
  serialize: _accountSchemaSerialize,
  deserialize: _accountSchemaDeserialize,
  deserializeProp: _accountSchemaDeserializeProp,
  idName: r'id',
  indexes: {
    r'accountId': IndexSchema(
      id: -1591555361937770434,
      name: r'accountId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'accountId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _accountSchemaGetId,
  getLinks: _accountSchemaGetLinks,
  attach: _accountSchemaAttach,
  version: '3.1.0+1',
);

int _accountSchemaEstimateSize(
  AccountSchema object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  bytesCount += 3 + object.displayName.length * 3;
  bytesCount += 3 + object.password.length * 3;
  bytesCount += 3 + object.server.length * 3;
  bytesCount += 3 + object.stunServer.length * 3;
  bytesCount += 3 + object.transport.length * 3;
  bytesCount += 3 + object.turnServer.length * 3;
  bytesCount += 3 + object.username.length * 3;
  return bytesCount;
}

void _accountSchemaSerialize(
  AccountSchema object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeBool(offsets[1], object.autoRegister);
  writer.writeString(offsets[2], object.displayName);
  writer.writeString(offsets[3], object.password);
  writer.writeString(offsets[4], object.server);
  writer.writeBool(offsets[5], object.srtpEnabled);
  writer.writeString(offsets[6], object.stunServer);
  writer.writeBool(offsets[7], object.tlsEnabled);
  writer.writeString(offsets[8], object.transport);
  writer.writeString(offsets[9], object.turnServer);
  writer.writeString(offsets[10], object.username);
}

AccountSchema _accountSchemaDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AccountSchema();
  object.accountId = reader.readString(offsets[0]);
  object.autoRegister = reader.readBool(offsets[1]);
  object.displayName = reader.readString(offsets[2]);
  object.id = id;
  object.password = reader.readString(offsets[3]);
  object.server = reader.readString(offsets[4]);
  object.srtpEnabled = reader.readBool(offsets[5]);
  object.stunServer = reader.readString(offsets[6]);
  object.tlsEnabled = reader.readBool(offsets[7]);
  object.transport = reader.readString(offsets[8]);
  object.turnServer = reader.readString(offsets[9]);
  object.username = reader.readString(offsets[10]);
  return object;
}

P _accountSchemaDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _accountSchemaGetId(AccountSchema object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _accountSchemaGetLinks(AccountSchema object) {
  return [];
}

void _accountSchemaAttach(
    IsarCollection<dynamic> col, Id id, AccountSchema object) {
  object.id = id;
}

extension AccountSchemaByIndex on IsarCollection<AccountSchema> {
  Future<AccountSchema?> getByAccountId(String accountId) {
    return getByIndex(r'accountId', [accountId]);
  }

  AccountSchema? getByAccountIdSync(String accountId) {
    return getByIndexSync(r'accountId', [accountId]);
  }

  Future<bool> deleteByAccountId(String accountId) {
    return deleteByIndex(r'accountId', [accountId]);
  }

  bool deleteByAccountIdSync(String accountId) {
    return deleteByIndexSync(r'accountId', [accountId]);
  }

  Future<List<AccountSchema?>> getAllByAccountId(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'accountId', values);
  }

  List<AccountSchema?> getAllByAccountIdSync(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'accountId', values);
  }

  Future<int> deleteAllByAccountId(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'accountId', values);
  }

  int deleteAllByAccountIdSync(List<String> accountIdValues) {
    final values = accountIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'accountId', values);
  }

  Future<Id> putByAccountId(AccountSchema object) {
    return putByIndex(r'accountId', object);
  }

  Id putByAccountIdSync(AccountSchema object, {bool saveLinks = true}) {
    return putByIndexSync(r'accountId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByAccountId(List<AccountSchema> objects) {
    return putAllByIndex(r'accountId', objects);
  }

  List<Id> putAllByAccountIdSync(List<AccountSchema> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'accountId', objects, saveLinks: saveLinks);
  }
}

extension AccountSchemaQueryWhereSort
    on QueryBuilder<AccountSchema, AccountSchema, QWhere> {
  QueryBuilder<AccountSchema, AccountSchema, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AccountSchemaQueryWhere
    on QueryBuilder<AccountSchema, AccountSchema, QWhereClause> {
  QueryBuilder<AccountSchema, AccountSchema, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterWhereClause>
      accountIdEqualTo(String accountId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'accountId',
        value: [accountId],
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterWhereClause>
      accountIdNotEqualTo(String accountId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'accountId',
              lower: [],
              upper: [accountId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'accountId',
              lower: [accountId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'accountId',
              lower: [accountId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'accountId',
              lower: [],
              upper: [accountId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension AccountSchemaQueryFilter
    on QueryBuilder<AccountSchema, AccountSchema, QFilterCondition> {
  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      accountIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      accountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      accountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      accountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'accountId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      accountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      accountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      accountIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      accountIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'accountId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accountId',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'accountId',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      autoRegisterEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoRegister',
        value: value,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      displayNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      displayNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      displayNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      displayNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'displayName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      displayNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      displayNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      displayNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      displayNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'displayName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      displayNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'displayName',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      displayNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'displayName',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition> idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'id',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'id',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition> idEqualTo(
      Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      idGreaterThan(
    Id? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition> idLessThan(
    Id? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition> idBetween(
    Id? lower,
    Id? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      passwordEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'password',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      passwordGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'password',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      passwordLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'password',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      passwordBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'password',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      passwordStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'password',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      passwordEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'password',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      passwordContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'password',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      passwordMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'password',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      passwordIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'password',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      passwordIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'password',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      serverEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'server',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      serverGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'server',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      serverLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'server',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      serverBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'server',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      serverStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'server',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      serverEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'server',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      serverContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'server',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      serverMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'server',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      serverIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'server',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      serverIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'server',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      srtpEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'srtpEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      stunServerEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stunServer',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      stunServerGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'stunServer',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      stunServerLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'stunServer',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      stunServerBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'stunServer',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      stunServerStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'stunServer',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      stunServerEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'stunServer',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      stunServerContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'stunServer',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      stunServerMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'stunServer',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      stunServerIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stunServer',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      stunServerIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'stunServer',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      tlsEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tlsEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      transportEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'transport',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      transportGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'transport',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      transportLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'transport',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      transportBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'transport',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      transportStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'transport',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      transportEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'transport',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      transportContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'transport',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      transportMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'transport',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      transportIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'transport',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      transportIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'transport',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      turnServerEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'turnServer',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      turnServerGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'turnServer',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      turnServerLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'turnServer',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      turnServerBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'turnServer',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      turnServerStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'turnServer',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      turnServerEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'turnServer',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      turnServerContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'turnServer',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      turnServerMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'turnServer',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      turnServerIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'turnServer',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      turnServerIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'turnServer',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      usernameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'username',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      usernameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'username',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      usernameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'username',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      usernameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'username',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      usernameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'username',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      usernameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'username',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      usernameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'username',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      usernameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'username',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      usernameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'username',
        value: '',
      ));
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterFilterCondition>
      usernameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'username',
        value: '',
      ));
    });
  }
}

extension AccountSchemaQueryObject
    on QueryBuilder<AccountSchema, AccountSchema, QFilterCondition> {}

extension AccountSchemaQueryLinks
    on QueryBuilder<AccountSchema, AccountSchema, QFilterCondition> {}

extension AccountSchemaQuerySortBy
    on QueryBuilder<AccountSchema, AccountSchema, QSortBy> {
  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      sortByAutoRegister() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoRegister', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      sortByAutoRegisterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoRegister', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> sortByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      sortByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> sortByPassword() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'password', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      sortByPasswordDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'password', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> sortByServer() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'server', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> sortByServerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'server', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> sortBySrtpEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'srtpEnabled', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      sortBySrtpEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'srtpEnabled', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> sortByStunServer() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stunServer', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      sortByStunServerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stunServer', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> sortByTlsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlsEnabled', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      sortByTlsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlsEnabled', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> sortByTransport() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transport', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      sortByTransportDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transport', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> sortByTurnServer() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'turnServer', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      sortByTurnServerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'turnServer', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> sortByUsername() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'username', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      sortByUsernameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'username', Sort.desc);
    });
  }
}

extension AccountSchemaQuerySortThenBy
    on QueryBuilder<AccountSchema, AccountSchema, QSortThenBy> {
  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      thenByAutoRegister() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoRegister', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      thenByAutoRegisterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoRegister', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      thenByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenByPassword() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'password', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      thenByPasswordDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'password', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenByServer() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'server', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenByServerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'server', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenBySrtpEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'srtpEnabled', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      thenBySrtpEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'srtpEnabled', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenByStunServer() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stunServer', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      thenByStunServerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stunServer', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenByTlsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlsEnabled', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      thenByTlsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlsEnabled', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenByTransport() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transport', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      thenByTransportDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transport', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenByTurnServer() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'turnServer', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      thenByTurnServerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'turnServer', Sort.desc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy> thenByUsername() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'username', Sort.asc);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QAfterSortBy>
      thenByUsernameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'username', Sort.desc);
    });
  }
}

extension AccountSchemaQueryWhereDistinct
    on QueryBuilder<AccountSchema, AccountSchema, QDistinct> {
  QueryBuilder<AccountSchema, AccountSchema, QDistinct> distinctByAccountId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accountId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QDistinct>
      distinctByAutoRegister() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoRegister');
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QDistinct> distinctByDisplayName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'displayName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QDistinct> distinctByPassword(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'password', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QDistinct> distinctByServer(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'server', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QDistinct>
      distinctBySrtpEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'srtpEnabled');
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QDistinct> distinctByStunServer(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stunServer', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QDistinct> distinctByTlsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tlsEnabled');
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QDistinct> distinctByTransport(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'transport', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QDistinct> distinctByTurnServer(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'turnServer', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AccountSchema, AccountSchema, QDistinct> distinctByUsername(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'username', caseSensitive: caseSensitive);
    });
  }
}

extension AccountSchemaQueryProperty
    on QueryBuilder<AccountSchema, AccountSchema, QQueryProperty> {
  QueryBuilder<AccountSchema, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AccountSchema, String, QQueryOperations> accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accountId');
    });
  }

  QueryBuilder<AccountSchema, bool, QQueryOperations> autoRegisterProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoRegister');
    });
  }

  QueryBuilder<AccountSchema, String, QQueryOperations> displayNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'displayName');
    });
  }

  QueryBuilder<AccountSchema, String, QQueryOperations> passwordProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'password');
    });
  }

  QueryBuilder<AccountSchema, String, QQueryOperations> serverProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'server');
    });
  }

  QueryBuilder<AccountSchema, bool, QQueryOperations> srtpEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'srtpEnabled');
    });
  }

  QueryBuilder<AccountSchema, String, QQueryOperations> stunServerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stunServer');
    });
  }

  QueryBuilder<AccountSchema, bool, QQueryOperations> tlsEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tlsEnabled');
    });
  }

  QueryBuilder<AccountSchema, String, QQueryOperations> transportProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'transport');
    });
  }

  QueryBuilder<AccountSchema, String, QQueryOperations> turnServerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'turnServer');
    });
  }

  QueryBuilder<AccountSchema, String, QQueryOperations> usernameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'username');
    });
  }
}
