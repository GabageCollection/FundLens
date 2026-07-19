// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $HoldingTableTable extends HoldingTable
    with TableInfo<$HoldingTableTable, HoldingTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HoldingTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePlatformMeta = const VerificationMeta(
    'sourcePlatform',
  );
  @override
  late final GeneratedColumn<String> sourcePlatform = GeneratedColumn<String>(
    'source_platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instrumentTypeMeta = const VerificationMeta(
    'instrumentType',
  );
  @override
  late final GeneratedColumn<String> instrumentType = GeneratedColumn<String>(
    'instrument_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetClassMeta = const VerificationMeta(
    'assetClass',
  );
  @override
  late final GeneratedColumn<String> assetClass = GeneratedColumn<String>(
    'asset_class',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productCodeMeta = const VerificationMeta(
    'productCode',
  );
  @override
  late final GeneratedColumn<String> productCode = GeneratedColumn<String>(
    'product_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<String> quantity = GeneratedColumn<String>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _availableQuantityMeta = const VerificationMeta(
    'availableQuantity',
  );
  @override
  late final GeneratedColumn<String> availableQuantity =
      GeneratedColumn<String>(
        'available_quantity',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _currentPriceMeta = const VerificationMeta(
    'currentPrice',
  );
  @override
  late final GeneratedColumn<String> currentPrice = GeneratedColumn<String>(
    'current_price',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costPriceMeta = const VerificationMeta(
    'costPrice',
  );
  @override
  late final GeneratedColumn<String> costPrice = GeneratedColumn<String>(
    'cost_price',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentValueMeta = const VerificationMeta(
    'currentValue',
  );
  @override
  late final GeneratedColumn<String> currentValue = GeneratedColumn<String>(
    'current_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costAmountMeta = const VerificationMeta(
    'costAmount',
  );
  @override
  late final GeneratedColumn<String> costAmount = GeneratedColumn<String>(
    'cost_amount',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _holdingProfitMeta = const VerificationMeta(
    'holdingProfit',
  );
  @override
  late final GeneratedColumn<String> holdingProfit = GeneratedColumn<String>(
    'holding_profit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _holdingReturnMeta = const VerificationMeta(
    'holdingReturn',
  );
  @override
  late final GeneratedColumn<String> holdingReturn = GeneratedColumn<String>(
    'holding_return',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyProfitMeta = const VerificationMeta(
    'dailyProfit',
  );
  @override
  late final GeneratedColumn<String> dailyProfit = GeneratedColumn<String>(
    'daily_profit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cumulativeProfitMeta = const VerificationMeta(
    'cumulativeProfit',
  );
  @override
  late final GeneratedColumn<String> cumulativeProfit = GeneratedColumn<String>(
    'cumulative_profit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _platformTagsMeta = const VerificationMeta(
    'platformTags',
  );
  @override
  late final GeneratedColumn<String> platformTags = GeneratedColumn<String>(
    'platform_tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _valuationMethodMeta = const VerificationMeta(
    'valuationMethod',
  );
  @override
  late final GeneratedColumn<String> valuationMethod = GeneratedColumn<String>(
    'valuation_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valuationDateMeta = const VerificationMeta(
    'valuationDate',
  );
  @override
  late final GeneratedColumn<int> valuationDate = GeneratedColumn<int>(
    'valuation_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataOriginMeta = const VerificationMeta(
    'dataOrigin',
  );
  @override
  late final GeneratedColumn<String> dataOrigin = GeneratedColumn<String>(
    'data_origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldProvenanceMeta = const VerificationMeta(
    'fieldProvenance',
  );
  @override
  late final GeneratedColumn<String> fieldProvenance = GeneratedColumn<String>(
    'field_provenance',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourcePlatform,
    instrumentType,
    assetClass,
    productName,
    productCode,
    currency,
    quantity,
    availableQuantity,
    currentPrice,
    costPrice,
    currentValue,
    costAmount,
    holdingProfit,
    holdingReturn,
    dailyProfit,
    cumulativeProfit,
    platformTags,
    valuationMethod,
    valuationDate,
    dataOrigin,
    fieldProvenance,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'holding';
  @override
  VerificationContext validateIntegrity(
    Insertable<HoldingTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_platform')) {
      context.handle(
        _sourcePlatformMeta,
        sourcePlatform.isAcceptableOrUnknown(
          data['source_platform']!,
          _sourcePlatformMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourcePlatformMeta);
    }
    if (data.containsKey('instrument_type')) {
      context.handle(
        _instrumentTypeMeta,
        instrumentType.isAcceptableOrUnknown(
          data['instrument_type']!,
          _instrumentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instrumentTypeMeta);
    }
    if (data.containsKey('asset_class')) {
      context.handle(
        _assetClassMeta,
        assetClass.isAcceptableOrUnknown(data['asset_class']!, _assetClassMeta),
      );
    } else if (isInserting) {
      context.missing(_assetClassMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('product_code')) {
      context.handle(
        _productCodeMeta,
        productCode.isAcceptableOrUnknown(
          data['product_code']!,
          _productCodeMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('available_quantity')) {
      context.handle(
        _availableQuantityMeta,
        availableQuantity.isAcceptableOrUnknown(
          data['available_quantity']!,
          _availableQuantityMeta,
        ),
      );
    }
    if (data.containsKey('current_price')) {
      context.handle(
        _currentPriceMeta,
        currentPrice.isAcceptableOrUnknown(
          data['current_price']!,
          _currentPriceMeta,
        ),
      );
    }
    if (data.containsKey('cost_price')) {
      context.handle(
        _costPriceMeta,
        costPrice.isAcceptableOrUnknown(data['cost_price']!, _costPriceMeta),
      );
    }
    if (data.containsKey('current_value')) {
      context.handle(
        _currentValueMeta,
        currentValue.isAcceptableOrUnknown(
          data['current_value']!,
          _currentValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentValueMeta);
    }
    if (data.containsKey('cost_amount')) {
      context.handle(
        _costAmountMeta,
        costAmount.isAcceptableOrUnknown(data['cost_amount']!, _costAmountMeta),
      );
    }
    if (data.containsKey('holding_profit')) {
      context.handle(
        _holdingProfitMeta,
        holdingProfit.isAcceptableOrUnknown(
          data['holding_profit']!,
          _holdingProfitMeta,
        ),
      );
    }
    if (data.containsKey('holding_return')) {
      context.handle(
        _holdingReturnMeta,
        holdingReturn.isAcceptableOrUnknown(
          data['holding_return']!,
          _holdingReturnMeta,
        ),
      );
    }
    if (data.containsKey('daily_profit')) {
      context.handle(
        _dailyProfitMeta,
        dailyProfit.isAcceptableOrUnknown(
          data['daily_profit']!,
          _dailyProfitMeta,
        ),
      );
    }
    if (data.containsKey('cumulative_profit')) {
      context.handle(
        _cumulativeProfitMeta,
        cumulativeProfit.isAcceptableOrUnknown(
          data['cumulative_profit']!,
          _cumulativeProfitMeta,
        ),
      );
    }
    if (data.containsKey('platform_tags')) {
      context.handle(
        _platformTagsMeta,
        platformTags.isAcceptableOrUnknown(
          data['platform_tags']!,
          _platformTagsMeta,
        ),
      );
    }
    if (data.containsKey('valuation_method')) {
      context.handle(
        _valuationMethodMeta,
        valuationMethod.isAcceptableOrUnknown(
          data['valuation_method']!,
          _valuationMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_valuationMethodMeta);
    }
    if (data.containsKey('valuation_date')) {
      context.handle(
        _valuationDateMeta,
        valuationDate.isAcceptableOrUnknown(
          data['valuation_date']!,
          _valuationDateMeta,
        ),
      );
    }
    if (data.containsKey('data_origin')) {
      context.handle(
        _dataOriginMeta,
        dataOrigin.isAcceptableOrUnknown(data['data_origin']!, _dataOriginMeta),
      );
    } else if (isInserting) {
      context.missing(_dataOriginMeta);
    }
    if (data.containsKey('field_provenance')) {
      context.handle(
        _fieldProvenanceMeta,
        fieldProvenance.isAcceptableOrUnknown(
          data['field_provenance']!,
          _fieldProvenanceMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HoldingTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HoldingTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourcePlatform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_platform'],
      )!,
      instrumentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_type'],
      )!,
      assetClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_class'],
      )!,
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      )!,
      productCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_code'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quantity'],
      ),
      availableQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}available_quantity'],
      ),
      currentPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_price'],
      ),
      costPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cost_price'],
      ),
      currentValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_value'],
      )!,
      costAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cost_amount'],
      ),
      holdingProfit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holding_profit'],
      ),
      holdingReturn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holding_return'],
      ),
      dailyProfit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}daily_profit'],
      ),
      cumulativeProfit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cumulative_profit'],
      ),
      platformTags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform_tags'],
      )!,
      valuationMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valuation_method'],
      )!,
      valuationDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}valuation_date'],
      ),
      dataOrigin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_origin'],
      )!,
      fieldProvenance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_provenance'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $HoldingTableTable createAlias(String alias) {
    return $HoldingTableTable(attachedDatabase, alias);
  }
}

class HoldingTableData extends DataClass
    implements Insertable<HoldingTableData> {
  final String id;
  final String sourcePlatform;
  final String instrumentType;
  final String assetClass;
  final String productName;
  final String? productCode;
  final String currency;
  final String? quantity;
  final String? availableQuantity;
  final String? currentPrice;
  final String? costPrice;
  final String currentValue;
  final String? costAmount;
  final String? holdingProfit;
  final String? holdingReturn;
  final String? dailyProfit;
  final String? cumulativeProfit;
  final String platformTags;
  final String valuationMethod;
  final int? valuationDate;
  final String dataOrigin;
  final String fieldProvenance;
  final String? note;
  final int createdAt;
  final int updatedAt;
  const HoldingTableData({
    required this.id,
    required this.sourcePlatform,
    required this.instrumentType,
    required this.assetClass,
    required this.productName,
    this.productCode,
    required this.currency,
    this.quantity,
    this.availableQuantity,
    this.currentPrice,
    this.costPrice,
    required this.currentValue,
    this.costAmount,
    this.holdingProfit,
    this.holdingReturn,
    this.dailyProfit,
    this.cumulativeProfit,
    required this.platformTags,
    required this.valuationMethod,
    this.valuationDate,
    required this.dataOrigin,
    required this.fieldProvenance,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_platform'] = Variable<String>(sourcePlatform);
    map['instrument_type'] = Variable<String>(instrumentType);
    map['asset_class'] = Variable<String>(assetClass);
    map['product_name'] = Variable<String>(productName);
    if (!nullToAbsent || productCode != null) {
      map['product_code'] = Variable<String>(productCode);
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<String>(quantity);
    }
    if (!nullToAbsent || availableQuantity != null) {
      map['available_quantity'] = Variable<String>(availableQuantity);
    }
    if (!nullToAbsent || currentPrice != null) {
      map['current_price'] = Variable<String>(currentPrice);
    }
    if (!nullToAbsent || costPrice != null) {
      map['cost_price'] = Variable<String>(costPrice);
    }
    map['current_value'] = Variable<String>(currentValue);
    if (!nullToAbsent || costAmount != null) {
      map['cost_amount'] = Variable<String>(costAmount);
    }
    if (!nullToAbsent || holdingProfit != null) {
      map['holding_profit'] = Variable<String>(holdingProfit);
    }
    if (!nullToAbsent || holdingReturn != null) {
      map['holding_return'] = Variable<String>(holdingReturn);
    }
    if (!nullToAbsent || dailyProfit != null) {
      map['daily_profit'] = Variable<String>(dailyProfit);
    }
    if (!nullToAbsent || cumulativeProfit != null) {
      map['cumulative_profit'] = Variable<String>(cumulativeProfit);
    }
    map['platform_tags'] = Variable<String>(platformTags);
    map['valuation_method'] = Variable<String>(valuationMethod);
    if (!nullToAbsent || valuationDate != null) {
      map['valuation_date'] = Variable<int>(valuationDate);
    }
    map['data_origin'] = Variable<String>(dataOrigin);
    map['field_provenance'] = Variable<String>(fieldProvenance);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  HoldingTableCompanion toCompanion(bool nullToAbsent) {
    return HoldingTableCompanion(
      id: Value(id),
      sourcePlatform: Value(sourcePlatform),
      instrumentType: Value(instrumentType),
      assetClass: Value(assetClass),
      productName: Value(productName),
      productCode: productCode == null && nullToAbsent
          ? const Value.absent()
          : Value(productCode),
      currency: Value(currency),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      availableQuantity: availableQuantity == null && nullToAbsent
          ? const Value.absent()
          : Value(availableQuantity),
      currentPrice: currentPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(currentPrice),
      costPrice: costPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(costPrice),
      currentValue: Value(currentValue),
      costAmount: costAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(costAmount),
      holdingProfit: holdingProfit == null && nullToAbsent
          ? const Value.absent()
          : Value(holdingProfit),
      holdingReturn: holdingReturn == null && nullToAbsent
          ? const Value.absent()
          : Value(holdingReturn),
      dailyProfit: dailyProfit == null && nullToAbsent
          ? const Value.absent()
          : Value(dailyProfit),
      cumulativeProfit: cumulativeProfit == null && nullToAbsent
          ? const Value.absent()
          : Value(cumulativeProfit),
      platformTags: Value(platformTags),
      valuationMethod: Value(valuationMethod),
      valuationDate: valuationDate == null && nullToAbsent
          ? const Value.absent()
          : Value(valuationDate),
      dataOrigin: Value(dataOrigin),
      fieldProvenance: Value(fieldProvenance),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory HoldingTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HoldingTableData(
      id: serializer.fromJson<String>(json['id']),
      sourcePlatform: serializer.fromJson<String>(json['sourcePlatform']),
      instrumentType: serializer.fromJson<String>(json['instrumentType']),
      assetClass: serializer.fromJson<String>(json['assetClass']),
      productName: serializer.fromJson<String>(json['productName']),
      productCode: serializer.fromJson<String?>(json['productCode']),
      currency: serializer.fromJson<String>(json['currency']),
      quantity: serializer.fromJson<String?>(json['quantity']),
      availableQuantity: serializer.fromJson<String?>(
        json['availableQuantity'],
      ),
      currentPrice: serializer.fromJson<String?>(json['currentPrice']),
      costPrice: serializer.fromJson<String?>(json['costPrice']),
      currentValue: serializer.fromJson<String>(json['currentValue']),
      costAmount: serializer.fromJson<String?>(json['costAmount']),
      holdingProfit: serializer.fromJson<String?>(json['holdingProfit']),
      holdingReturn: serializer.fromJson<String?>(json['holdingReturn']),
      dailyProfit: serializer.fromJson<String?>(json['dailyProfit']),
      cumulativeProfit: serializer.fromJson<String?>(json['cumulativeProfit']),
      platformTags: serializer.fromJson<String>(json['platformTags']),
      valuationMethod: serializer.fromJson<String>(json['valuationMethod']),
      valuationDate: serializer.fromJson<int?>(json['valuationDate']),
      dataOrigin: serializer.fromJson<String>(json['dataOrigin']),
      fieldProvenance: serializer.fromJson<String>(json['fieldProvenance']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourcePlatform': serializer.toJson<String>(sourcePlatform),
      'instrumentType': serializer.toJson<String>(instrumentType),
      'assetClass': serializer.toJson<String>(assetClass),
      'productName': serializer.toJson<String>(productName),
      'productCode': serializer.toJson<String?>(productCode),
      'currency': serializer.toJson<String>(currency),
      'quantity': serializer.toJson<String?>(quantity),
      'availableQuantity': serializer.toJson<String?>(availableQuantity),
      'currentPrice': serializer.toJson<String?>(currentPrice),
      'costPrice': serializer.toJson<String?>(costPrice),
      'currentValue': serializer.toJson<String>(currentValue),
      'costAmount': serializer.toJson<String?>(costAmount),
      'holdingProfit': serializer.toJson<String?>(holdingProfit),
      'holdingReturn': serializer.toJson<String?>(holdingReturn),
      'dailyProfit': serializer.toJson<String?>(dailyProfit),
      'cumulativeProfit': serializer.toJson<String?>(cumulativeProfit),
      'platformTags': serializer.toJson<String>(platformTags),
      'valuationMethod': serializer.toJson<String>(valuationMethod),
      'valuationDate': serializer.toJson<int?>(valuationDate),
      'dataOrigin': serializer.toJson<String>(dataOrigin),
      'fieldProvenance': serializer.toJson<String>(fieldProvenance),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  HoldingTableData copyWith({
    String? id,
    String? sourcePlatform,
    String? instrumentType,
    String? assetClass,
    String? productName,
    Value<String?> productCode = const Value.absent(),
    String? currency,
    Value<String?> quantity = const Value.absent(),
    Value<String?> availableQuantity = const Value.absent(),
    Value<String?> currentPrice = const Value.absent(),
    Value<String?> costPrice = const Value.absent(),
    String? currentValue,
    Value<String?> costAmount = const Value.absent(),
    Value<String?> holdingProfit = const Value.absent(),
    Value<String?> holdingReturn = const Value.absent(),
    Value<String?> dailyProfit = const Value.absent(),
    Value<String?> cumulativeProfit = const Value.absent(),
    String? platformTags,
    String? valuationMethod,
    Value<int?> valuationDate = const Value.absent(),
    String? dataOrigin,
    String? fieldProvenance,
    Value<String?> note = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => HoldingTableData(
    id: id ?? this.id,
    sourcePlatform: sourcePlatform ?? this.sourcePlatform,
    instrumentType: instrumentType ?? this.instrumentType,
    assetClass: assetClass ?? this.assetClass,
    productName: productName ?? this.productName,
    productCode: productCode.present ? productCode.value : this.productCode,
    currency: currency ?? this.currency,
    quantity: quantity.present ? quantity.value : this.quantity,
    availableQuantity: availableQuantity.present
        ? availableQuantity.value
        : this.availableQuantity,
    currentPrice: currentPrice.present ? currentPrice.value : this.currentPrice,
    costPrice: costPrice.present ? costPrice.value : this.costPrice,
    currentValue: currentValue ?? this.currentValue,
    costAmount: costAmount.present ? costAmount.value : this.costAmount,
    holdingProfit: holdingProfit.present
        ? holdingProfit.value
        : this.holdingProfit,
    holdingReturn: holdingReturn.present
        ? holdingReturn.value
        : this.holdingReturn,
    dailyProfit: dailyProfit.present ? dailyProfit.value : this.dailyProfit,
    cumulativeProfit: cumulativeProfit.present
        ? cumulativeProfit.value
        : this.cumulativeProfit,
    platformTags: platformTags ?? this.platformTags,
    valuationMethod: valuationMethod ?? this.valuationMethod,
    valuationDate: valuationDate.present
        ? valuationDate.value
        : this.valuationDate,
    dataOrigin: dataOrigin ?? this.dataOrigin,
    fieldProvenance: fieldProvenance ?? this.fieldProvenance,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  HoldingTableData copyWithCompanion(HoldingTableCompanion data) {
    return HoldingTableData(
      id: data.id.present ? data.id.value : this.id,
      sourcePlatform: data.sourcePlatform.present
          ? data.sourcePlatform.value
          : this.sourcePlatform,
      instrumentType: data.instrumentType.present
          ? data.instrumentType.value
          : this.instrumentType,
      assetClass: data.assetClass.present
          ? data.assetClass.value
          : this.assetClass,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      productCode: data.productCode.present
          ? data.productCode.value
          : this.productCode,
      currency: data.currency.present ? data.currency.value : this.currency,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      availableQuantity: data.availableQuantity.present
          ? data.availableQuantity.value
          : this.availableQuantity,
      currentPrice: data.currentPrice.present
          ? data.currentPrice.value
          : this.currentPrice,
      costPrice: data.costPrice.present ? data.costPrice.value : this.costPrice,
      currentValue: data.currentValue.present
          ? data.currentValue.value
          : this.currentValue,
      costAmount: data.costAmount.present
          ? data.costAmount.value
          : this.costAmount,
      holdingProfit: data.holdingProfit.present
          ? data.holdingProfit.value
          : this.holdingProfit,
      holdingReturn: data.holdingReturn.present
          ? data.holdingReturn.value
          : this.holdingReturn,
      dailyProfit: data.dailyProfit.present
          ? data.dailyProfit.value
          : this.dailyProfit,
      cumulativeProfit: data.cumulativeProfit.present
          ? data.cumulativeProfit.value
          : this.cumulativeProfit,
      platformTags: data.platformTags.present
          ? data.platformTags.value
          : this.platformTags,
      valuationMethod: data.valuationMethod.present
          ? data.valuationMethod.value
          : this.valuationMethod,
      valuationDate: data.valuationDate.present
          ? data.valuationDate.value
          : this.valuationDate,
      dataOrigin: data.dataOrigin.present
          ? data.dataOrigin.value
          : this.dataOrigin,
      fieldProvenance: data.fieldProvenance.present
          ? data.fieldProvenance.value
          : this.fieldProvenance,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HoldingTableData(')
          ..write('id: $id, ')
          ..write('sourcePlatform: $sourcePlatform, ')
          ..write('instrumentType: $instrumentType, ')
          ..write('assetClass: $assetClass, ')
          ..write('productName: $productName, ')
          ..write('productCode: $productCode, ')
          ..write('currency: $currency, ')
          ..write('quantity: $quantity, ')
          ..write('availableQuantity: $availableQuantity, ')
          ..write('currentPrice: $currentPrice, ')
          ..write('costPrice: $costPrice, ')
          ..write('currentValue: $currentValue, ')
          ..write('costAmount: $costAmount, ')
          ..write('holdingProfit: $holdingProfit, ')
          ..write('holdingReturn: $holdingReturn, ')
          ..write('dailyProfit: $dailyProfit, ')
          ..write('cumulativeProfit: $cumulativeProfit, ')
          ..write('platformTags: $platformTags, ')
          ..write('valuationMethod: $valuationMethod, ')
          ..write('valuationDate: $valuationDate, ')
          ..write('dataOrigin: $dataOrigin, ')
          ..write('fieldProvenance: $fieldProvenance, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    sourcePlatform,
    instrumentType,
    assetClass,
    productName,
    productCode,
    currency,
    quantity,
    availableQuantity,
    currentPrice,
    costPrice,
    currentValue,
    costAmount,
    holdingProfit,
    holdingReturn,
    dailyProfit,
    cumulativeProfit,
    platformTags,
    valuationMethod,
    valuationDate,
    dataOrigin,
    fieldProvenance,
    note,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HoldingTableData &&
          other.id == this.id &&
          other.sourcePlatform == this.sourcePlatform &&
          other.instrumentType == this.instrumentType &&
          other.assetClass == this.assetClass &&
          other.productName == this.productName &&
          other.productCode == this.productCode &&
          other.currency == this.currency &&
          other.quantity == this.quantity &&
          other.availableQuantity == this.availableQuantity &&
          other.currentPrice == this.currentPrice &&
          other.costPrice == this.costPrice &&
          other.currentValue == this.currentValue &&
          other.costAmount == this.costAmount &&
          other.holdingProfit == this.holdingProfit &&
          other.holdingReturn == this.holdingReturn &&
          other.dailyProfit == this.dailyProfit &&
          other.cumulativeProfit == this.cumulativeProfit &&
          other.platformTags == this.platformTags &&
          other.valuationMethod == this.valuationMethod &&
          other.valuationDate == this.valuationDate &&
          other.dataOrigin == this.dataOrigin &&
          other.fieldProvenance == this.fieldProvenance &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class HoldingTableCompanion extends UpdateCompanion<HoldingTableData> {
  final Value<String> id;
  final Value<String> sourcePlatform;
  final Value<String> instrumentType;
  final Value<String> assetClass;
  final Value<String> productName;
  final Value<String?> productCode;
  final Value<String> currency;
  final Value<String?> quantity;
  final Value<String?> availableQuantity;
  final Value<String?> currentPrice;
  final Value<String?> costPrice;
  final Value<String> currentValue;
  final Value<String?> costAmount;
  final Value<String?> holdingProfit;
  final Value<String?> holdingReturn;
  final Value<String?> dailyProfit;
  final Value<String?> cumulativeProfit;
  final Value<String> platformTags;
  final Value<String> valuationMethod;
  final Value<int?> valuationDate;
  final Value<String> dataOrigin;
  final Value<String> fieldProvenance;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const HoldingTableCompanion({
    this.id = const Value.absent(),
    this.sourcePlatform = const Value.absent(),
    this.instrumentType = const Value.absent(),
    this.assetClass = const Value.absent(),
    this.productName = const Value.absent(),
    this.productCode = const Value.absent(),
    this.currency = const Value.absent(),
    this.quantity = const Value.absent(),
    this.availableQuantity = const Value.absent(),
    this.currentPrice = const Value.absent(),
    this.costPrice = const Value.absent(),
    this.currentValue = const Value.absent(),
    this.costAmount = const Value.absent(),
    this.holdingProfit = const Value.absent(),
    this.holdingReturn = const Value.absent(),
    this.dailyProfit = const Value.absent(),
    this.cumulativeProfit = const Value.absent(),
    this.platformTags = const Value.absent(),
    this.valuationMethod = const Value.absent(),
    this.valuationDate = const Value.absent(),
    this.dataOrigin = const Value.absent(),
    this.fieldProvenance = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HoldingTableCompanion.insert({
    required String id,
    required String sourcePlatform,
    required String instrumentType,
    required String assetClass,
    required String productName,
    this.productCode = const Value.absent(),
    required String currency,
    this.quantity = const Value.absent(),
    this.availableQuantity = const Value.absent(),
    this.currentPrice = const Value.absent(),
    this.costPrice = const Value.absent(),
    required String currentValue,
    this.costAmount = const Value.absent(),
    this.holdingProfit = const Value.absent(),
    this.holdingReturn = const Value.absent(),
    this.dailyProfit = const Value.absent(),
    this.cumulativeProfit = const Value.absent(),
    this.platformTags = const Value.absent(),
    required String valuationMethod,
    this.valuationDate = const Value.absent(),
    required String dataOrigin,
    this.fieldProvenance = const Value.absent(),
    this.note = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourcePlatform = Value(sourcePlatform),
       instrumentType = Value(instrumentType),
       assetClass = Value(assetClass),
       productName = Value(productName),
       currency = Value(currency),
       currentValue = Value(currentValue),
       valuationMethod = Value(valuationMethod),
       dataOrigin = Value(dataOrigin),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<HoldingTableData> custom({
    Expression<String>? id,
    Expression<String>? sourcePlatform,
    Expression<String>? instrumentType,
    Expression<String>? assetClass,
    Expression<String>? productName,
    Expression<String>? productCode,
    Expression<String>? currency,
    Expression<String>? quantity,
    Expression<String>? availableQuantity,
    Expression<String>? currentPrice,
    Expression<String>? costPrice,
    Expression<String>? currentValue,
    Expression<String>? costAmount,
    Expression<String>? holdingProfit,
    Expression<String>? holdingReturn,
    Expression<String>? dailyProfit,
    Expression<String>? cumulativeProfit,
    Expression<String>? platformTags,
    Expression<String>? valuationMethod,
    Expression<int>? valuationDate,
    Expression<String>? dataOrigin,
    Expression<String>? fieldProvenance,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourcePlatform != null) 'source_platform': sourcePlatform,
      if (instrumentType != null) 'instrument_type': instrumentType,
      if (assetClass != null) 'asset_class': assetClass,
      if (productName != null) 'product_name': productName,
      if (productCode != null) 'product_code': productCode,
      if (currency != null) 'currency': currency,
      if (quantity != null) 'quantity': quantity,
      if (availableQuantity != null) 'available_quantity': availableQuantity,
      if (currentPrice != null) 'current_price': currentPrice,
      if (costPrice != null) 'cost_price': costPrice,
      if (currentValue != null) 'current_value': currentValue,
      if (costAmount != null) 'cost_amount': costAmount,
      if (holdingProfit != null) 'holding_profit': holdingProfit,
      if (holdingReturn != null) 'holding_return': holdingReturn,
      if (dailyProfit != null) 'daily_profit': dailyProfit,
      if (cumulativeProfit != null) 'cumulative_profit': cumulativeProfit,
      if (platformTags != null) 'platform_tags': platformTags,
      if (valuationMethod != null) 'valuation_method': valuationMethod,
      if (valuationDate != null) 'valuation_date': valuationDate,
      if (dataOrigin != null) 'data_origin': dataOrigin,
      if (fieldProvenance != null) 'field_provenance': fieldProvenance,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HoldingTableCompanion copyWith({
    Value<String>? id,
    Value<String>? sourcePlatform,
    Value<String>? instrumentType,
    Value<String>? assetClass,
    Value<String>? productName,
    Value<String?>? productCode,
    Value<String>? currency,
    Value<String?>? quantity,
    Value<String?>? availableQuantity,
    Value<String?>? currentPrice,
    Value<String?>? costPrice,
    Value<String>? currentValue,
    Value<String?>? costAmount,
    Value<String?>? holdingProfit,
    Value<String?>? holdingReturn,
    Value<String?>? dailyProfit,
    Value<String?>? cumulativeProfit,
    Value<String>? platformTags,
    Value<String>? valuationMethod,
    Value<int?>? valuationDate,
    Value<String>? dataOrigin,
    Value<String>? fieldProvenance,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return HoldingTableCompanion(
      id: id ?? this.id,
      sourcePlatform: sourcePlatform ?? this.sourcePlatform,
      instrumentType: instrumentType ?? this.instrumentType,
      assetClass: assetClass ?? this.assetClass,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      currency: currency ?? this.currency,
      quantity: quantity ?? this.quantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      currentPrice: currentPrice ?? this.currentPrice,
      costPrice: costPrice ?? this.costPrice,
      currentValue: currentValue ?? this.currentValue,
      costAmount: costAmount ?? this.costAmount,
      holdingProfit: holdingProfit ?? this.holdingProfit,
      holdingReturn: holdingReturn ?? this.holdingReturn,
      dailyProfit: dailyProfit ?? this.dailyProfit,
      cumulativeProfit: cumulativeProfit ?? this.cumulativeProfit,
      platformTags: platformTags ?? this.platformTags,
      valuationMethod: valuationMethod ?? this.valuationMethod,
      valuationDate: valuationDate ?? this.valuationDate,
      dataOrigin: dataOrigin ?? this.dataOrigin,
      fieldProvenance: fieldProvenance ?? this.fieldProvenance,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourcePlatform.present) {
      map['source_platform'] = Variable<String>(sourcePlatform.value);
    }
    if (instrumentType.present) {
      map['instrument_type'] = Variable<String>(instrumentType.value);
    }
    if (assetClass.present) {
      map['asset_class'] = Variable<String>(assetClass.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (productCode.present) {
      map['product_code'] = Variable<String>(productCode.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<String>(quantity.value);
    }
    if (availableQuantity.present) {
      map['available_quantity'] = Variable<String>(availableQuantity.value);
    }
    if (currentPrice.present) {
      map['current_price'] = Variable<String>(currentPrice.value);
    }
    if (costPrice.present) {
      map['cost_price'] = Variable<String>(costPrice.value);
    }
    if (currentValue.present) {
      map['current_value'] = Variable<String>(currentValue.value);
    }
    if (costAmount.present) {
      map['cost_amount'] = Variable<String>(costAmount.value);
    }
    if (holdingProfit.present) {
      map['holding_profit'] = Variable<String>(holdingProfit.value);
    }
    if (holdingReturn.present) {
      map['holding_return'] = Variable<String>(holdingReturn.value);
    }
    if (dailyProfit.present) {
      map['daily_profit'] = Variable<String>(dailyProfit.value);
    }
    if (cumulativeProfit.present) {
      map['cumulative_profit'] = Variable<String>(cumulativeProfit.value);
    }
    if (platformTags.present) {
      map['platform_tags'] = Variable<String>(platformTags.value);
    }
    if (valuationMethod.present) {
      map['valuation_method'] = Variable<String>(valuationMethod.value);
    }
    if (valuationDate.present) {
      map['valuation_date'] = Variable<int>(valuationDate.value);
    }
    if (dataOrigin.present) {
      map['data_origin'] = Variable<String>(dataOrigin.value);
    }
    if (fieldProvenance.present) {
      map['field_provenance'] = Variable<String>(fieldProvenance.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HoldingTableCompanion(')
          ..write('id: $id, ')
          ..write('sourcePlatform: $sourcePlatform, ')
          ..write('instrumentType: $instrumentType, ')
          ..write('assetClass: $assetClass, ')
          ..write('productName: $productName, ')
          ..write('productCode: $productCode, ')
          ..write('currency: $currency, ')
          ..write('quantity: $quantity, ')
          ..write('availableQuantity: $availableQuantity, ')
          ..write('currentPrice: $currentPrice, ')
          ..write('costPrice: $costPrice, ')
          ..write('currentValue: $currentValue, ')
          ..write('costAmount: $costAmount, ')
          ..write('holdingProfit: $holdingProfit, ')
          ..write('holdingReturn: $holdingReturn, ')
          ..write('dailyProfit: $dailyProfit, ')
          ..write('cumulativeProfit: $cumulativeProfit, ')
          ..write('platformTags: $platformTags, ')
          ..write('valuationMethod: $valuationMethod, ')
          ..write('valuationDate: $valuationDate, ')
          ..write('dataOrigin: $dataOrigin, ')
          ..write('fieldProvenance: $fieldProvenance, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SnapshotTableTable extends SnapshotTable
    with TableInfo<$SnapshotTableTable, SnapshotTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnapshotTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, label, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshot';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SnapshotTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SnapshotTableTable createAlias(String alias) {
    return $SnapshotTableTable(attachedDatabase, alias);
  }
}

class SnapshotTableData extends DataClass
    implements Insertable<SnapshotTableData> {
  final String id;
  final String label;
  final int createdAt;
  const SnapshotTableData({
    required this.id,
    required this.label,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SnapshotTableCompanion toCompanion(bool nullToAbsent) {
    return SnapshotTableCompanion(
      id: Value(id),
      label: Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory SnapshotTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotTableData(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  SnapshotTableData copyWith({String? id, String? label, int? createdAt}) =>
      SnapshotTableData(
        id: id ?? this.id,
        label: label ?? this.label,
        createdAt: createdAt ?? this.createdAt,
      );
  SnapshotTableData copyWithCompanion(SnapshotTableCompanion data) {
    return SnapshotTableData(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotTableData(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, label, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotTableData &&
          other.id == this.id &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class SnapshotTableCompanion extends UpdateCompanion<SnapshotTableData> {
  final Value<String> id;
  final Value<String> label;
  final Value<int> createdAt;
  final Value<int> rowid;
  const SnapshotTableCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SnapshotTableCompanion.insert({
    required String id,
    required String label,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       label = Value(label),
       createdAt = Value(createdAt);
  static Insertable<SnapshotTableData> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SnapshotTableCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return SnapshotTableCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotTableCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SnapshotHoldingTableTable extends SnapshotHoldingTable
    with TableInfo<$SnapshotHoldingTableTable, SnapshotHoldingTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnapshotHoldingTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _snapshotIdMeta = const VerificationMeta(
    'snapshotId',
  );
  @override
  late final GeneratedColumn<String> snapshotId = GeneratedColumn<String>(
    'snapshot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES snapshot (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _holdingIdMeta = const VerificationMeta(
    'holdingId',
  );
  @override
  late final GeneratedColumn<String> holdingId = GeneratedColumn<String>(
    'holding_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePlatformMeta = const VerificationMeta(
    'sourcePlatform',
  );
  @override
  late final GeneratedColumn<String> sourcePlatform = GeneratedColumn<String>(
    'source_platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instrumentTypeMeta = const VerificationMeta(
    'instrumentType',
  );
  @override
  late final GeneratedColumn<String> instrumentType = GeneratedColumn<String>(
    'instrument_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetClassMeta = const VerificationMeta(
    'assetClass',
  );
  @override
  late final GeneratedColumn<String> assetClass = GeneratedColumn<String>(
    'asset_class',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productCodeMeta = const VerificationMeta(
    'productCode',
  );
  @override
  late final GeneratedColumn<String> productCode = GeneratedColumn<String>(
    'product_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<String> quantity = GeneratedColumn<String>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentPriceMeta = const VerificationMeta(
    'currentPrice',
  );
  @override
  late final GeneratedColumn<String> currentPrice = GeneratedColumn<String>(
    'current_price',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentValueMeta = const VerificationMeta(
    'currentValue',
  );
  @override
  late final GeneratedColumn<String> currentValue = GeneratedColumn<String>(
    'current_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costAmountMeta = const VerificationMeta(
    'costAmount',
  );
  @override
  late final GeneratedColumn<String> costAmount = GeneratedColumn<String>(
    'cost_amount',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _holdingProfitMeta = const VerificationMeta(
    'holdingProfit',
  );
  @override
  late final GeneratedColumn<String> holdingProfit = GeneratedColumn<String>(
    'holding_profit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyProfitMeta = const VerificationMeta(
    'dailyProfit',
  );
  @override
  late final GeneratedColumn<String> dailyProfit = GeneratedColumn<String>(
    'daily_profit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cumulativeProfitMeta = const VerificationMeta(
    'cumulativeProfit',
  );
  @override
  late final GeneratedColumn<String> cumulativeProfit = GeneratedColumn<String>(
    'cumulative_profit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valuationDateMeta = const VerificationMeta(
    'valuationDate',
  );
  @override
  late final GeneratedColumn<int> valuationDate = GeneratedColumn<int>(
    'valuation_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fieldProvenanceMeta = const VerificationMeta(
    'fieldProvenance',
  );
  @override
  late final GeneratedColumn<String> fieldProvenance = GeneratedColumn<String>(
    'field_provenance',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    snapshotId,
    holdingId,
    sourcePlatform,
    instrumentType,
    assetClass,
    productName,
    productCode,
    currency,
    quantity,
    currentPrice,
    currentValue,
    costAmount,
    holdingProfit,
    dailyProfit,
    cumulativeProfit,
    valuationDate,
    fieldProvenance,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshot_holding';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotHoldingTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('snapshot_id')) {
      context.handle(
        _snapshotIdMeta,
        snapshotId.isAcceptableOrUnknown(data['snapshot_id']!, _snapshotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_snapshotIdMeta);
    }
    if (data.containsKey('holding_id')) {
      context.handle(
        _holdingIdMeta,
        holdingId.isAcceptableOrUnknown(data['holding_id']!, _holdingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_holdingIdMeta);
    }
    if (data.containsKey('source_platform')) {
      context.handle(
        _sourcePlatformMeta,
        sourcePlatform.isAcceptableOrUnknown(
          data['source_platform']!,
          _sourcePlatformMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourcePlatformMeta);
    }
    if (data.containsKey('instrument_type')) {
      context.handle(
        _instrumentTypeMeta,
        instrumentType.isAcceptableOrUnknown(
          data['instrument_type']!,
          _instrumentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instrumentTypeMeta);
    }
    if (data.containsKey('asset_class')) {
      context.handle(
        _assetClassMeta,
        assetClass.isAcceptableOrUnknown(data['asset_class']!, _assetClassMeta),
      );
    } else if (isInserting) {
      context.missing(_assetClassMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('product_code')) {
      context.handle(
        _productCodeMeta,
        productCode.isAcceptableOrUnknown(
          data['product_code']!,
          _productCodeMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('current_price')) {
      context.handle(
        _currentPriceMeta,
        currentPrice.isAcceptableOrUnknown(
          data['current_price']!,
          _currentPriceMeta,
        ),
      );
    }
    if (data.containsKey('current_value')) {
      context.handle(
        _currentValueMeta,
        currentValue.isAcceptableOrUnknown(
          data['current_value']!,
          _currentValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentValueMeta);
    }
    if (data.containsKey('cost_amount')) {
      context.handle(
        _costAmountMeta,
        costAmount.isAcceptableOrUnknown(data['cost_amount']!, _costAmountMeta),
      );
    }
    if (data.containsKey('holding_profit')) {
      context.handle(
        _holdingProfitMeta,
        holdingProfit.isAcceptableOrUnknown(
          data['holding_profit']!,
          _holdingProfitMeta,
        ),
      );
    }
    if (data.containsKey('daily_profit')) {
      context.handle(
        _dailyProfitMeta,
        dailyProfit.isAcceptableOrUnknown(
          data['daily_profit']!,
          _dailyProfitMeta,
        ),
      );
    }
    if (data.containsKey('cumulative_profit')) {
      context.handle(
        _cumulativeProfitMeta,
        cumulativeProfit.isAcceptableOrUnknown(
          data['cumulative_profit']!,
          _cumulativeProfitMeta,
        ),
      );
    }
    if (data.containsKey('valuation_date')) {
      context.handle(
        _valuationDateMeta,
        valuationDate.isAcceptableOrUnknown(
          data['valuation_date']!,
          _valuationDateMeta,
        ),
      );
    }
    if (data.containsKey('field_provenance')) {
      context.handle(
        _fieldProvenanceMeta,
        fieldProvenance.isAcceptableOrUnknown(
          data['field_provenance']!,
          _fieldProvenanceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SnapshotHoldingTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotHoldingTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      snapshotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_id'],
      )!,
      holdingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holding_id'],
      )!,
      sourcePlatform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_platform'],
      )!,
      instrumentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_type'],
      )!,
      assetClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_class'],
      )!,
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      )!,
      productCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_code'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quantity'],
      ),
      currentPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_price'],
      ),
      currentValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_value'],
      )!,
      costAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cost_amount'],
      ),
      holdingProfit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holding_profit'],
      ),
      dailyProfit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}daily_profit'],
      ),
      cumulativeProfit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cumulative_profit'],
      ),
      valuationDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}valuation_date'],
      ),
      fieldProvenance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_provenance'],
      )!,
    );
  }

  @override
  $SnapshotHoldingTableTable createAlias(String alias) {
    return $SnapshotHoldingTableTable(attachedDatabase, alias);
  }
}

class SnapshotHoldingTableData extends DataClass
    implements Insertable<SnapshotHoldingTableData> {
  final int id;
  final String snapshotId;
  final String holdingId;
  final String sourcePlatform;
  final String instrumentType;
  final String assetClass;
  final String productName;
  final String? productCode;
  final String currency;
  final String? quantity;
  final String? currentPrice;
  final String currentValue;
  final String? costAmount;
  final String? holdingProfit;
  final String? dailyProfit;
  final String? cumulativeProfit;
  final int? valuationDate;
  final String fieldProvenance;
  const SnapshotHoldingTableData({
    required this.id,
    required this.snapshotId,
    required this.holdingId,
    required this.sourcePlatform,
    required this.instrumentType,
    required this.assetClass,
    required this.productName,
    this.productCode,
    required this.currency,
    this.quantity,
    this.currentPrice,
    required this.currentValue,
    this.costAmount,
    this.holdingProfit,
    this.dailyProfit,
    this.cumulativeProfit,
    this.valuationDate,
    required this.fieldProvenance,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['snapshot_id'] = Variable<String>(snapshotId);
    map['holding_id'] = Variable<String>(holdingId);
    map['source_platform'] = Variable<String>(sourcePlatform);
    map['instrument_type'] = Variable<String>(instrumentType);
    map['asset_class'] = Variable<String>(assetClass);
    map['product_name'] = Variable<String>(productName);
    if (!nullToAbsent || productCode != null) {
      map['product_code'] = Variable<String>(productCode);
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<String>(quantity);
    }
    if (!nullToAbsent || currentPrice != null) {
      map['current_price'] = Variable<String>(currentPrice);
    }
    map['current_value'] = Variable<String>(currentValue);
    if (!nullToAbsent || costAmount != null) {
      map['cost_amount'] = Variable<String>(costAmount);
    }
    if (!nullToAbsent || holdingProfit != null) {
      map['holding_profit'] = Variable<String>(holdingProfit);
    }
    if (!nullToAbsent || dailyProfit != null) {
      map['daily_profit'] = Variable<String>(dailyProfit);
    }
    if (!nullToAbsent || cumulativeProfit != null) {
      map['cumulative_profit'] = Variable<String>(cumulativeProfit);
    }
    if (!nullToAbsent || valuationDate != null) {
      map['valuation_date'] = Variable<int>(valuationDate);
    }
    map['field_provenance'] = Variable<String>(fieldProvenance);
    return map;
  }

  SnapshotHoldingTableCompanion toCompanion(bool nullToAbsent) {
    return SnapshotHoldingTableCompanion(
      id: Value(id),
      snapshotId: Value(snapshotId),
      holdingId: Value(holdingId),
      sourcePlatform: Value(sourcePlatform),
      instrumentType: Value(instrumentType),
      assetClass: Value(assetClass),
      productName: Value(productName),
      productCode: productCode == null && nullToAbsent
          ? const Value.absent()
          : Value(productCode),
      currency: Value(currency),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      currentPrice: currentPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(currentPrice),
      currentValue: Value(currentValue),
      costAmount: costAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(costAmount),
      holdingProfit: holdingProfit == null && nullToAbsent
          ? const Value.absent()
          : Value(holdingProfit),
      dailyProfit: dailyProfit == null && nullToAbsent
          ? const Value.absent()
          : Value(dailyProfit),
      cumulativeProfit: cumulativeProfit == null && nullToAbsent
          ? const Value.absent()
          : Value(cumulativeProfit),
      valuationDate: valuationDate == null && nullToAbsent
          ? const Value.absent()
          : Value(valuationDate),
      fieldProvenance: Value(fieldProvenance),
    );
  }

  factory SnapshotHoldingTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotHoldingTableData(
      id: serializer.fromJson<int>(json['id']),
      snapshotId: serializer.fromJson<String>(json['snapshotId']),
      holdingId: serializer.fromJson<String>(json['holdingId']),
      sourcePlatform: serializer.fromJson<String>(json['sourcePlatform']),
      instrumentType: serializer.fromJson<String>(json['instrumentType']),
      assetClass: serializer.fromJson<String>(json['assetClass']),
      productName: serializer.fromJson<String>(json['productName']),
      productCode: serializer.fromJson<String?>(json['productCode']),
      currency: serializer.fromJson<String>(json['currency']),
      quantity: serializer.fromJson<String?>(json['quantity']),
      currentPrice: serializer.fromJson<String?>(json['currentPrice']),
      currentValue: serializer.fromJson<String>(json['currentValue']),
      costAmount: serializer.fromJson<String?>(json['costAmount']),
      holdingProfit: serializer.fromJson<String?>(json['holdingProfit']),
      dailyProfit: serializer.fromJson<String?>(json['dailyProfit']),
      cumulativeProfit: serializer.fromJson<String?>(json['cumulativeProfit']),
      valuationDate: serializer.fromJson<int?>(json['valuationDate']),
      fieldProvenance: serializer.fromJson<String>(json['fieldProvenance']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'snapshotId': serializer.toJson<String>(snapshotId),
      'holdingId': serializer.toJson<String>(holdingId),
      'sourcePlatform': serializer.toJson<String>(sourcePlatform),
      'instrumentType': serializer.toJson<String>(instrumentType),
      'assetClass': serializer.toJson<String>(assetClass),
      'productName': serializer.toJson<String>(productName),
      'productCode': serializer.toJson<String?>(productCode),
      'currency': serializer.toJson<String>(currency),
      'quantity': serializer.toJson<String?>(quantity),
      'currentPrice': serializer.toJson<String?>(currentPrice),
      'currentValue': serializer.toJson<String>(currentValue),
      'costAmount': serializer.toJson<String?>(costAmount),
      'holdingProfit': serializer.toJson<String?>(holdingProfit),
      'dailyProfit': serializer.toJson<String?>(dailyProfit),
      'cumulativeProfit': serializer.toJson<String?>(cumulativeProfit),
      'valuationDate': serializer.toJson<int?>(valuationDate),
      'fieldProvenance': serializer.toJson<String>(fieldProvenance),
    };
  }

  SnapshotHoldingTableData copyWith({
    int? id,
    String? snapshotId,
    String? holdingId,
    String? sourcePlatform,
    String? instrumentType,
    String? assetClass,
    String? productName,
    Value<String?> productCode = const Value.absent(),
    String? currency,
    Value<String?> quantity = const Value.absent(),
    Value<String?> currentPrice = const Value.absent(),
    String? currentValue,
    Value<String?> costAmount = const Value.absent(),
    Value<String?> holdingProfit = const Value.absent(),
    Value<String?> dailyProfit = const Value.absent(),
    Value<String?> cumulativeProfit = const Value.absent(),
    Value<int?> valuationDate = const Value.absent(),
    String? fieldProvenance,
  }) => SnapshotHoldingTableData(
    id: id ?? this.id,
    snapshotId: snapshotId ?? this.snapshotId,
    holdingId: holdingId ?? this.holdingId,
    sourcePlatform: sourcePlatform ?? this.sourcePlatform,
    instrumentType: instrumentType ?? this.instrumentType,
    assetClass: assetClass ?? this.assetClass,
    productName: productName ?? this.productName,
    productCode: productCode.present ? productCode.value : this.productCode,
    currency: currency ?? this.currency,
    quantity: quantity.present ? quantity.value : this.quantity,
    currentPrice: currentPrice.present ? currentPrice.value : this.currentPrice,
    currentValue: currentValue ?? this.currentValue,
    costAmount: costAmount.present ? costAmount.value : this.costAmount,
    holdingProfit: holdingProfit.present
        ? holdingProfit.value
        : this.holdingProfit,
    dailyProfit: dailyProfit.present ? dailyProfit.value : this.dailyProfit,
    cumulativeProfit: cumulativeProfit.present
        ? cumulativeProfit.value
        : this.cumulativeProfit,
    valuationDate: valuationDate.present
        ? valuationDate.value
        : this.valuationDate,
    fieldProvenance: fieldProvenance ?? this.fieldProvenance,
  );
  SnapshotHoldingTableData copyWithCompanion(
    SnapshotHoldingTableCompanion data,
  ) {
    return SnapshotHoldingTableData(
      id: data.id.present ? data.id.value : this.id,
      snapshotId: data.snapshotId.present
          ? data.snapshotId.value
          : this.snapshotId,
      holdingId: data.holdingId.present ? data.holdingId.value : this.holdingId,
      sourcePlatform: data.sourcePlatform.present
          ? data.sourcePlatform.value
          : this.sourcePlatform,
      instrumentType: data.instrumentType.present
          ? data.instrumentType.value
          : this.instrumentType,
      assetClass: data.assetClass.present
          ? data.assetClass.value
          : this.assetClass,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      productCode: data.productCode.present
          ? data.productCode.value
          : this.productCode,
      currency: data.currency.present ? data.currency.value : this.currency,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      currentPrice: data.currentPrice.present
          ? data.currentPrice.value
          : this.currentPrice,
      currentValue: data.currentValue.present
          ? data.currentValue.value
          : this.currentValue,
      costAmount: data.costAmount.present
          ? data.costAmount.value
          : this.costAmount,
      holdingProfit: data.holdingProfit.present
          ? data.holdingProfit.value
          : this.holdingProfit,
      dailyProfit: data.dailyProfit.present
          ? data.dailyProfit.value
          : this.dailyProfit,
      cumulativeProfit: data.cumulativeProfit.present
          ? data.cumulativeProfit.value
          : this.cumulativeProfit,
      valuationDate: data.valuationDate.present
          ? data.valuationDate.value
          : this.valuationDate,
      fieldProvenance: data.fieldProvenance.present
          ? data.fieldProvenance.value
          : this.fieldProvenance,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotHoldingTableData(')
          ..write('id: $id, ')
          ..write('snapshotId: $snapshotId, ')
          ..write('holdingId: $holdingId, ')
          ..write('sourcePlatform: $sourcePlatform, ')
          ..write('instrumentType: $instrumentType, ')
          ..write('assetClass: $assetClass, ')
          ..write('productName: $productName, ')
          ..write('productCode: $productCode, ')
          ..write('currency: $currency, ')
          ..write('quantity: $quantity, ')
          ..write('currentPrice: $currentPrice, ')
          ..write('currentValue: $currentValue, ')
          ..write('costAmount: $costAmount, ')
          ..write('holdingProfit: $holdingProfit, ')
          ..write('dailyProfit: $dailyProfit, ')
          ..write('cumulativeProfit: $cumulativeProfit, ')
          ..write('valuationDate: $valuationDate, ')
          ..write('fieldProvenance: $fieldProvenance')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    snapshotId,
    holdingId,
    sourcePlatform,
    instrumentType,
    assetClass,
    productName,
    productCode,
    currency,
    quantity,
    currentPrice,
    currentValue,
    costAmount,
    holdingProfit,
    dailyProfit,
    cumulativeProfit,
    valuationDate,
    fieldProvenance,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotHoldingTableData &&
          other.id == this.id &&
          other.snapshotId == this.snapshotId &&
          other.holdingId == this.holdingId &&
          other.sourcePlatform == this.sourcePlatform &&
          other.instrumentType == this.instrumentType &&
          other.assetClass == this.assetClass &&
          other.productName == this.productName &&
          other.productCode == this.productCode &&
          other.currency == this.currency &&
          other.quantity == this.quantity &&
          other.currentPrice == this.currentPrice &&
          other.currentValue == this.currentValue &&
          other.costAmount == this.costAmount &&
          other.holdingProfit == this.holdingProfit &&
          other.dailyProfit == this.dailyProfit &&
          other.cumulativeProfit == this.cumulativeProfit &&
          other.valuationDate == this.valuationDate &&
          other.fieldProvenance == this.fieldProvenance);
}

class SnapshotHoldingTableCompanion
    extends UpdateCompanion<SnapshotHoldingTableData> {
  final Value<int> id;
  final Value<String> snapshotId;
  final Value<String> holdingId;
  final Value<String> sourcePlatform;
  final Value<String> instrumentType;
  final Value<String> assetClass;
  final Value<String> productName;
  final Value<String?> productCode;
  final Value<String> currency;
  final Value<String?> quantity;
  final Value<String?> currentPrice;
  final Value<String> currentValue;
  final Value<String?> costAmount;
  final Value<String?> holdingProfit;
  final Value<String?> dailyProfit;
  final Value<String?> cumulativeProfit;
  final Value<int?> valuationDate;
  final Value<String> fieldProvenance;
  const SnapshotHoldingTableCompanion({
    this.id = const Value.absent(),
    this.snapshotId = const Value.absent(),
    this.holdingId = const Value.absent(),
    this.sourcePlatform = const Value.absent(),
    this.instrumentType = const Value.absent(),
    this.assetClass = const Value.absent(),
    this.productName = const Value.absent(),
    this.productCode = const Value.absent(),
    this.currency = const Value.absent(),
    this.quantity = const Value.absent(),
    this.currentPrice = const Value.absent(),
    this.currentValue = const Value.absent(),
    this.costAmount = const Value.absent(),
    this.holdingProfit = const Value.absent(),
    this.dailyProfit = const Value.absent(),
    this.cumulativeProfit = const Value.absent(),
    this.valuationDate = const Value.absent(),
    this.fieldProvenance = const Value.absent(),
  });
  SnapshotHoldingTableCompanion.insert({
    this.id = const Value.absent(),
    required String snapshotId,
    required String holdingId,
    required String sourcePlatform,
    required String instrumentType,
    required String assetClass,
    required String productName,
    this.productCode = const Value.absent(),
    required String currency,
    this.quantity = const Value.absent(),
    this.currentPrice = const Value.absent(),
    required String currentValue,
    this.costAmount = const Value.absent(),
    this.holdingProfit = const Value.absent(),
    this.dailyProfit = const Value.absent(),
    this.cumulativeProfit = const Value.absent(),
    this.valuationDate = const Value.absent(),
    this.fieldProvenance = const Value.absent(),
  }) : snapshotId = Value(snapshotId),
       holdingId = Value(holdingId),
       sourcePlatform = Value(sourcePlatform),
       instrumentType = Value(instrumentType),
       assetClass = Value(assetClass),
       productName = Value(productName),
       currency = Value(currency),
       currentValue = Value(currentValue);
  static Insertable<SnapshotHoldingTableData> custom({
    Expression<int>? id,
    Expression<String>? snapshotId,
    Expression<String>? holdingId,
    Expression<String>? sourcePlatform,
    Expression<String>? instrumentType,
    Expression<String>? assetClass,
    Expression<String>? productName,
    Expression<String>? productCode,
    Expression<String>? currency,
    Expression<String>? quantity,
    Expression<String>? currentPrice,
    Expression<String>? currentValue,
    Expression<String>? costAmount,
    Expression<String>? holdingProfit,
    Expression<String>? dailyProfit,
    Expression<String>? cumulativeProfit,
    Expression<int>? valuationDate,
    Expression<String>? fieldProvenance,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (snapshotId != null) 'snapshot_id': snapshotId,
      if (holdingId != null) 'holding_id': holdingId,
      if (sourcePlatform != null) 'source_platform': sourcePlatform,
      if (instrumentType != null) 'instrument_type': instrumentType,
      if (assetClass != null) 'asset_class': assetClass,
      if (productName != null) 'product_name': productName,
      if (productCode != null) 'product_code': productCode,
      if (currency != null) 'currency': currency,
      if (quantity != null) 'quantity': quantity,
      if (currentPrice != null) 'current_price': currentPrice,
      if (currentValue != null) 'current_value': currentValue,
      if (costAmount != null) 'cost_amount': costAmount,
      if (holdingProfit != null) 'holding_profit': holdingProfit,
      if (dailyProfit != null) 'daily_profit': dailyProfit,
      if (cumulativeProfit != null) 'cumulative_profit': cumulativeProfit,
      if (valuationDate != null) 'valuation_date': valuationDate,
      if (fieldProvenance != null) 'field_provenance': fieldProvenance,
    });
  }

  SnapshotHoldingTableCompanion copyWith({
    Value<int>? id,
    Value<String>? snapshotId,
    Value<String>? holdingId,
    Value<String>? sourcePlatform,
    Value<String>? instrumentType,
    Value<String>? assetClass,
    Value<String>? productName,
    Value<String?>? productCode,
    Value<String>? currency,
    Value<String?>? quantity,
    Value<String?>? currentPrice,
    Value<String>? currentValue,
    Value<String?>? costAmount,
    Value<String?>? holdingProfit,
    Value<String?>? dailyProfit,
    Value<String?>? cumulativeProfit,
    Value<int?>? valuationDate,
    Value<String>? fieldProvenance,
  }) {
    return SnapshotHoldingTableCompanion(
      id: id ?? this.id,
      snapshotId: snapshotId ?? this.snapshotId,
      holdingId: holdingId ?? this.holdingId,
      sourcePlatform: sourcePlatform ?? this.sourcePlatform,
      instrumentType: instrumentType ?? this.instrumentType,
      assetClass: assetClass ?? this.assetClass,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      currency: currency ?? this.currency,
      quantity: quantity ?? this.quantity,
      currentPrice: currentPrice ?? this.currentPrice,
      currentValue: currentValue ?? this.currentValue,
      costAmount: costAmount ?? this.costAmount,
      holdingProfit: holdingProfit ?? this.holdingProfit,
      dailyProfit: dailyProfit ?? this.dailyProfit,
      cumulativeProfit: cumulativeProfit ?? this.cumulativeProfit,
      valuationDate: valuationDate ?? this.valuationDate,
      fieldProvenance: fieldProvenance ?? this.fieldProvenance,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (snapshotId.present) {
      map['snapshot_id'] = Variable<String>(snapshotId.value);
    }
    if (holdingId.present) {
      map['holding_id'] = Variable<String>(holdingId.value);
    }
    if (sourcePlatform.present) {
      map['source_platform'] = Variable<String>(sourcePlatform.value);
    }
    if (instrumentType.present) {
      map['instrument_type'] = Variable<String>(instrumentType.value);
    }
    if (assetClass.present) {
      map['asset_class'] = Variable<String>(assetClass.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (productCode.present) {
      map['product_code'] = Variable<String>(productCode.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<String>(quantity.value);
    }
    if (currentPrice.present) {
      map['current_price'] = Variable<String>(currentPrice.value);
    }
    if (currentValue.present) {
      map['current_value'] = Variable<String>(currentValue.value);
    }
    if (costAmount.present) {
      map['cost_amount'] = Variable<String>(costAmount.value);
    }
    if (holdingProfit.present) {
      map['holding_profit'] = Variable<String>(holdingProfit.value);
    }
    if (dailyProfit.present) {
      map['daily_profit'] = Variable<String>(dailyProfit.value);
    }
    if (cumulativeProfit.present) {
      map['cumulative_profit'] = Variable<String>(cumulativeProfit.value);
    }
    if (valuationDate.present) {
      map['valuation_date'] = Variable<int>(valuationDate.value);
    }
    if (fieldProvenance.present) {
      map['field_provenance'] = Variable<String>(fieldProvenance.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotHoldingTableCompanion(')
          ..write('id: $id, ')
          ..write('snapshotId: $snapshotId, ')
          ..write('holdingId: $holdingId, ')
          ..write('sourcePlatform: $sourcePlatform, ')
          ..write('instrumentType: $instrumentType, ')
          ..write('assetClass: $assetClass, ')
          ..write('productName: $productName, ')
          ..write('productCode: $productCode, ')
          ..write('currency: $currency, ')
          ..write('quantity: $quantity, ')
          ..write('currentPrice: $currentPrice, ')
          ..write('currentValue: $currentValue, ')
          ..write('costAmount: $costAmount, ')
          ..write('holdingProfit: $holdingProfit, ')
          ..write('dailyProfit: $dailyProfit, ')
          ..write('cumulativeProfit: $cumulativeProfit, ')
          ..write('valuationDate: $valuationDate, ')
          ..write('fieldProvenance: $fieldProvenance')
          ..write(')'))
        .toString();
  }
}

class $ImportBatchTableTable extends ImportBatchTable
    with TableInfo<$ImportBatchTableTable, ImportBatchTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportBatchTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePlatformMeta = const VerificationMeta(
    'sourcePlatform',
  );
  @override
  late final GeneratedColumn<String> sourcePlatform = GeneratedColumn<String>(
    'source_platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<int> importedAt = GeneratedColumn<int>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawDataHashMeta = const VerificationMeta(
    'rawDataHash',
  );
  @override
  late final GeneratedColumn<String> rawDataHash = GeneratedColumn<String>(
    'raw_data_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourcePlatform,
    importedAt,
    rawDataHash,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_batch';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportBatchTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_platform')) {
      context.handle(
        _sourcePlatformMeta,
        sourcePlatform.isAcceptableOrUnknown(
          data['source_platform']!,
          _sourcePlatformMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourcePlatformMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('raw_data_hash')) {
      context.handle(
        _rawDataHashMeta,
        rawDataHash.isAcceptableOrUnknown(
          data['raw_data_hash']!,
          _rawDataHashMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportBatchTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportBatchTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourcePlatform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_platform'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_at'],
      )!,
      rawDataHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_data_hash'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $ImportBatchTableTable createAlias(String alias) {
    return $ImportBatchTableTable(attachedDatabase, alias);
  }
}

class ImportBatchTableData extends DataClass
    implements Insertable<ImportBatchTableData> {
  final String id;
  final String sourcePlatform;
  final int importedAt;
  final String? rawDataHash;
  final String status;
  const ImportBatchTableData({
    required this.id,
    required this.sourcePlatform,
    required this.importedAt,
    this.rawDataHash,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_platform'] = Variable<String>(sourcePlatform);
    map['imported_at'] = Variable<int>(importedAt);
    if (!nullToAbsent || rawDataHash != null) {
      map['raw_data_hash'] = Variable<String>(rawDataHash);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  ImportBatchTableCompanion toCompanion(bool nullToAbsent) {
    return ImportBatchTableCompanion(
      id: Value(id),
      sourcePlatform: Value(sourcePlatform),
      importedAt: Value(importedAt),
      rawDataHash: rawDataHash == null && nullToAbsent
          ? const Value.absent()
          : Value(rawDataHash),
      status: Value(status),
    );
  }

  factory ImportBatchTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportBatchTableData(
      id: serializer.fromJson<String>(json['id']),
      sourcePlatform: serializer.fromJson<String>(json['sourcePlatform']),
      importedAt: serializer.fromJson<int>(json['importedAt']),
      rawDataHash: serializer.fromJson<String?>(json['rawDataHash']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourcePlatform': serializer.toJson<String>(sourcePlatform),
      'importedAt': serializer.toJson<int>(importedAt),
      'rawDataHash': serializer.toJson<String?>(rawDataHash),
      'status': serializer.toJson<String>(status),
    };
  }

  ImportBatchTableData copyWith({
    String? id,
    String? sourcePlatform,
    int? importedAt,
    Value<String?> rawDataHash = const Value.absent(),
    String? status,
  }) => ImportBatchTableData(
    id: id ?? this.id,
    sourcePlatform: sourcePlatform ?? this.sourcePlatform,
    importedAt: importedAt ?? this.importedAt,
    rawDataHash: rawDataHash.present ? rawDataHash.value : this.rawDataHash,
    status: status ?? this.status,
  );
  ImportBatchTableData copyWithCompanion(ImportBatchTableCompanion data) {
    return ImportBatchTableData(
      id: data.id.present ? data.id.value : this.id,
      sourcePlatform: data.sourcePlatform.present
          ? data.sourcePlatform.value
          : this.sourcePlatform,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      rawDataHash: data.rawDataHash.present
          ? data.rawDataHash.value
          : this.rawDataHash,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportBatchTableData(')
          ..write('id: $id, ')
          ..write('sourcePlatform: $sourcePlatform, ')
          ..write('importedAt: $importedAt, ')
          ..write('rawDataHash: $rawDataHash, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sourcePlatform, importedAt, rawDataHash, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportBatchTableData &&
          other.id == this.id &&
          other.sourcePlatform == this.sourcePlatform &&
          other.importedAt == this.importedAt &&
          other.rawDataHash == this.rawDataHash &&
          other.status == this.status);
}

class ImportBatchTableCompanion extends UpdateCompanion<ImportBatchTableData> {
  final Value<String> id;
  final Value<String> sourcePlatform;
  final Value<int> importedAt;
  final Value<String?> rawDataHash;
  final Value<String> status;
  final Value<int> rowid;
  const ImportBatchTableCompanion({
    this.id = const Value.absent(),
    this.sourcePlatform = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rawDataHash = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportBatchTableCompanion.insert({
    required String id,
    required String sourcePlatform,
    required int importedAt,
    this.rawDataHash = const Value.absent(),
    required String status,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourcePlatform = Value(sourcePlatform),
       importedAt = Value(importedAt),
       status = Value(status);
  static Insertable<ImportBatchTableData> custom({
    Expression<String>? id,
    Expression<String>? sourcePlatform,
    Expression<int>? importedAt,
    Expression<String>? rawDataHash,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourcePlatform != null) 'source_platform': sourcePlatform,
      if (importedAt != null) 'imported_at': importedAt,
      if (rawDataHash != null) 'raw_data_hash': rawDataHash,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportBatchTableCompanion copyWith({
    Value<String>? id,
    Value<String>? sourcePlatform,
    Value<int>? importedAt,
    Value<String?>? rawDataHash,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return ImportBatchTableCompanion(
      id: id ?? this.id,
      sourcePlatform: sourcePlatform ?? this.sourcePlatform,
      importedAt: importedAt ?? this.importedAt,
      rawDataHash: rawDataHash ?? this.rawDataHash,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourcePlatform.present) {
      map['source_platform'] = Variable<String>(sourcePlatform.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<int>(importedAt.value);
    }
    if (rawDataHash.present) {
      map['raw_data_hash'] = Variable<String>(rawDataHash.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportBatchTableCompanion(')
          ..write('id: $id, ')
          ..write('sourcePlatform: $sourcePlatform, ')
          ..write('importedAt: $importedAt, ')
          ..write('rawDataHash: $rawDataHash, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DraftHoldingTableTable extends DraftHoldingTable
    with TableInfo<$DraftHoldingTableTable, DraftHoldingTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftHoldingTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importBatchIdMeta = const VerificationMeta(
    'importBatchId',
  );
  @override
  late final GeneratedColumn<String> importBatchId = GeneratedColumn<String>(
    'import_batch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES import_batch (id)',
    ),
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    importBatchId,
    rawJson,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'draft_holding';
  @override
  VerificationContext validateIntegrity(
    Insertable<DraftHoldingTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('import_batch_id')) {
      context.handle(
        _importBatchIdMeta,
        importBatchId.isAcceptableOrUnknown(
          data['import_batch_id']!,
          _importBatchIdMeta,
        ),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_rawJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DraftHoldingTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftHoldingTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      importBatchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_batch_id'],
      ),
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DraftHoldingTableTable createAlias(String alias) {
    return $DraftHoldingTableTable(attachedDatabase, alias);
  }
}

class DraftHoldingTableData extends DataClass
    implements Insertable<DraftHoldingTableData> {
  final String id;
  final String? importBatchId;
  final String rawJson;
  final String status;
  final int createdAt;
  const DraftHoldingTableData({
    required this.id,
    this.importBatchId,
    required this.rawJson,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || importBatchId != null) {
      map['import_batch_id'] = Variable<String>(importBatchId);
    }
    map['raw_json'] = Variable<String>(rawJson);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  DraftHoldingTableCompanion toCompanion(bool nullToAbsent) {
    return DraftHoldingTableCompanion(
      id: Value(id),
      importBatchId: importBatchId == null && nullToAbsent
          ? const Value.absent()
          : Value(importBatchId),
      rawJson: Value(rawJson),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory DraftHoldingTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftHoldingTableData(
      id: serializer.fromJson<String>(json['id']),
      importBatchId: serializer.fromJson<String?>(json['importBatchId']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'importBatchId': serializer.toJson<String?>(importBatchId),
      'rawJson': serializer.toJson<String>(rawJson),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  DraftHoldingTableData copyWith({
    String? id,
    Value<String?> importBatchId = const Value.absent(),
    String? rawJson,
    String? status,
    int? createdAt,
  }) => DraftHoldingTableData(
    id: id ?? this.id,
    importBatchId: importBatchId.present
        ? importBatchId.value
        : this.importBatchId,
    rawJson: rawJson ?? this.rawJson,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  DraftHoldingTableData copyWithCompanion(DraftHoldingTableCompanion data) {
    return DraftHoldingTableData(
      id: data.id.present ? data.id.value : this.id,
      importBatchId: data.importBatchId.present
          ? data.importBatchId.value
          : this.importBatchId,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftHoldingTableData(')
          ..write('id: $id, ')
          ..write('importBatchId: $importBatchId, ')
          ..write('rawJson: $rawJson, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, importBatchId, rawJson, status, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftHoldingTableData &&
          other.id == this.id &&
          other.importBatchId == this.importBatchId &&
          other.rawJson == this.rawJson &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class DraftHoldingTableCompanion
    extends UpdateCompanion<DraftHoldingTableData> {
  final Value<String> id;
  final Value<String?> importBatchId;
  final Value<String> rawJson;
  final Value<String> status;
  final Value<int> createdAt;
  final Value<int> rowid;
  const DraftHoldingTableCompanion({
    this.id = const Value.absent(),
    this.importBatchId = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftHoldingTableCompanion.insert({
    required String id,
    this.importBatchId = const Value.absent(),
    required String rawJson,
    required String status,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       rawJson = Value(rawJson),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<DraftHoldingTableData> custom({
    Expression<String>? id,
    Expression<String>? importBatchId,
    Expression<String>? rawJson,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (importBatchId != null) 'import_batch_id': importBatchId,
      if (rawJson != null) 'raw_json': rawJson,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftHoldingTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? importBatchId,
    Value<String>? rawJson,
    Value<String>? status,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return DraftHoldingTableCompanion(
      id: id ?? this.id,
      importBatchId: importBatchId ?? this.importBatchId,
      rawJson: rawJson ?? this.rawJson,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (importBatchId.present) {
      map['import_batch_id'] = Variable<String>(importBatchId.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftHoldingTableCompanion(')
          ..write('id: $id, ')
          ..write('importBatchId: $importBatchId, ')
          ..write('rawJson: $rawJson, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DataIssueTableTable extends DataIssueTable
    with TableInfo<$DataIssueTableTable, DataIssueTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DataIssueTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _holdingIdMeta = const VerificationMeta(
    'holdingId',
  );
  @override
  late final GeneratedColumn<String> holdingId = GeneratedColumn<String>(
    'holding_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES holding (id)',
    ),
  );
  static const VerificationMeta _issueTypeMeta = const VerificationMeta(
    'issueType',
  );
  @override
  late final GeneratedColumn<String> issueType = GeneratedColumn<String>(
    'issue_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<int> resolvedAt = GeneratedColumn<int>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    holdingId,
    issueType,
    description,
    createdAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'data_issue';
  @override
  VerificationContext validateIntegrity(
    Insertable<DataIssueTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('holding_id')) {
      context.handle(
        _holdingIdMeta,
        holdingId.isAcceptableOrUnknown(data['holding_id']!, _holdingIdMeta),
      );
    }
    if (data.containsKey('issue_type')) {
      context.handle(
        _issueTypeMeta,
        issueType.isAcceptableOrUnknown(data['issue_type']!, _issueTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_issueTypeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DataIssueTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DataIssueTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      holdingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holding_id'],
      ),
      issueType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issue_type'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $DataIssueTableTable createAlias(String alias) {
    return $DataIssueTableTable(attachedDatabase, alias);
  }
}

class DataIssueTableData extends DataClass
    implements Insertable<DataIssueTableData> {
  final String id;
  final String? holdingId;
  final String issueType;
  final String description;
  final int createdAt;
  final int? resolvedAt;
  const DataIssueTableData({
    required this.id,
    this.holdingId,
    required this.issueType,
    required this.description,
    required this.createdAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || holdingId != null) {
      map['holding_id'] = Variable<String>(holdingId);
    }
    map['issue_type'] = Variable<String>(issueType);
    map['description'] = Variable<String>(description);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<int>(resolvedAt);
    }
    return map;
  }

  DataIssueTableCompanion toCompanion(bool nullToAbsent) {
    return DataIssueTableCompanion(
      id: Value(id),
      holdingId: holdingId == null && nullToAbsent
          ? const Value.absent()
          : Value(holdingId),
      issueType: Value(issueType),
      description: Value(description),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory DataIssueTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DataIssueTableData(
      id: serializer.fromJson<String>(json['id']),
      holdingId: serializer.fromJson<String?>(json['holdingId']),
      issueType: serializer.fromJson<String>(json['issueType']),
      description: serializer.fromJson<String>(json['description']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      resolvedAt: serializer.fromJson<int?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'holdingId': serializer.toJson<String?>(holdingId),
      'issueType': serializer.toJson<String>(issueType),
      'description': serializer.toJson<String>(description),
      'createdAt': serializer.toJson<int>(createdAt),
      'resolvedAt': serializer.toJson<int?>(resolvedAt),
    };
  }

  DataIssueTableData copyWith({
    String? id,
    Value<String?> holdingId = const Value.absent(),
    String? issueType,
    String? description,
    int? createdAt,
    Value<int?> resolvedAt = const Value.absent(),
  }) => DataIssueTableData(
    id: id ?? this.id,
    holdingId: holdingId.present ? holdingId.value : this.holdingId,
    issueType: issueType ?? this.issueType,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  DataIssueTableData copyWithCompanion(DataIssueTableCompanion data) {
    return DataIssueTableData(
      id: data.id.present ? data.id.value : this.id,
      holdingId: data.holdingId.present ? data.holdingId.value : this.holdingId,
      issueType: data.issueType.present ? data.issueType.value : this.issueType,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DataIssueTableData(')
          ..write('id: $id, ')
          ..write('holdingId: $holdingId, ')
          ..write('issueType: $issueType, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, holdingId, issueType, description, createdAt, resolvedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DataIssueTableData &&
          other.id == this.id &&
          other.holdingId == this.holdingId &&
          other.issueType == this.issueType &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class DataIssueTableCompanion extends UpdateCompanion<DataIssueTableData> {
  final Value<String> id;
  final Value<String?> holdingId;
  final Value<String> issueType;
  final Value<String> description;
  final Value<int> createdAt;
  final Value<int?> resolvedAt;
  final Value<int> rowid;
  const DataIssueTableCompanion({
    this.id = const Value.absent(),
    this.holdingId = const Value.absent(),
    this.issueType = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DataIssueTableCompanion.insert({
    required String id,
    this.holdingId = const Value.absent(),
    required String issueType,
    required String description,
    required int createdAt,
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       issueType = Value(issueType),
       description = Value(description),
       createdAt = Value(createdAt);
  static Insertable<DataIssueTableData> custom({
    Expression<String>? id,
    Expression<String>? holdingId,
    Expression<String>? issueType,
    Expression<String>? description,
    Expression<int>? createdAt,
    Expression<int>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (holdingId != null) 'holding_id': holdingId,
      if (issueType != null) 'issue_type': issueType,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DataIssueTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? holdingId,
    Value<String>? issueType,
    Value<String>? description,
    Value<int>? createdAt,
    Value<int?>? resolvedAt,
    Value<int>? rowid,
  }) {
    return DataIssueTableCompanion(
      id: id ?? this.id,
      holdingId: holdingId ?? this.holdingId,
      issueType: issueType ?? this.issueType,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (holdingId.present) {
      map['holding_id'] = Variable<String>(holdingId.value);
    }
    if (issueType.present) {
      map['issue_type'] = Variable<String>(issueType.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<int>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DataIssueTableCompanion(')
          ..write('id: $id, ')
          ..write('holdingId: $holdingId, ')
          ..write('issueType: $issueType, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuoteCacheTableTable extends QuoteCacheTable
    with TableInfo<$QuoteCacheTableTable, QuoteCacheTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuoteCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _productCodeMeta = const VerificationMeta(
    'productCode',
  );
  @override
  late final GeneratedColumn<String> productCode = GeneratedColumn<String>(
    'product_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<String> price = GeneratedColumn<String>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    productCode,
    productName,
    price,
    fetchedAt,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quote_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuoteCacheTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('product_code')) {
      context.handle(
        _productCodeMeta,
        productCode.isAcceptableOrUnknown(
          data['product_code']!,
          _productCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productCodeMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {productCode};
  @override
  QuoteCacheTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuoteCacheTableData(
      productCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_code'],
      )!,
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      ),
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $QuoteCacheTableTable createAlias(String alias) {
    return $QuoteCacheTableTable(attachedDatabase, alias);
  }
}

class QuoteCacheTableData extends DataClass
    implements Insertable<QuoteCacheTableData> {
  final String productCode;
  final String? productName;
  final String? price;
  final int fetchedAt;
  final String source;
  const QuoteCacheTableData({
    required this.productCode,
    this.productName,
    this.price,
    required this.fetchedAt,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['product_code'] = Variable<String>(productCode);
    if (!nullToAbsent || productName != null) {
      map['product_name'] = Variable<String>(productName);
    }
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<String>(price);
    }
    map['fetched_at'] = Variable<int>(fetchedAt);
    map['source'] = Variable<String>(source);
    return map;
  }

  QuoteCacheTableCompanion toCompanion(bool nullToAbsent) {
    return QuoteCacheTableCompanion(
      productCode: Value(productCode),
      productName: productName == null && nullToAbsent
          ? const Value.absent()
          : Value(productName),
      price: price == null && nullToAbsent
          ? const Value.absent()
          : Value(price),
      fetchedAt: Value(fetchedAt),
      source: Value(source),
    );
  }

  factory QuoteCacheTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuoteCacheTableData(
      productCode: serializer.fromJson<String>(json['productCode']),
      productName: serializer.fromJson<String?>(json['productName']),
      price: serializer.fromJson<String?>(json['price']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'productCode': serializer.toJson<String>(productCode),
      'productName': serializer.toJson<String?>(productName),
      'price': serializer.toJson<String?>(price),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
      'source': serializer.toJson<String>(source),
    };
  }

  QuoteCacheTableData copyWith({
    String? productCode,
    Value<String?> productName = const Value.absent(),
    Value<String?> price = const Value.absent(),
    int? fetchedAt,
    String? source,
  }) => QuoteCacheTableData(
    productCode: productCode ?? this.productCode,
    productName: productName.present ? productName.value : this.productName,
    price: price.present ? price.value : this.price,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    source: source ?? this.source,
  );
  QuoteCacheTableData copyWithCompanion(QuoteCacheTableCompanion data) {
    return QuoteCacheTableData(
      productCode: data.productCode.present
          ? data.productCode.value
          : this.productCode,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      price: data.price.present ? data.price.value : this.price,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuoteCacheTableData(')
          ..write('productCode: $productCode, ')
          ..write('productName: $productName, ')
          ..write('price: $price, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(productCode, productName, price, fetchedAt, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuoteCacheTableData &&
          other.productCode == this.productCode &&
          other.productName == this.productName &&
          other.price == this.price &&
          other.fetchedAt == this.fetchedAt &&
          other.source == this.source);
}

class QuoteCacheTableCompanion extends UpdateCompanion<QuoteCacheTableData> {
  final Value<String> productCode;
  final Value<String?> productName;
  final Value<String?> price;
  final Value<int> fetchedAt;
  final Value<String> source;
  final Value<int> rowid;
  const QuoteCacheTableCompanion({
    this.productCode = const Value.absent(),
    this.productName = const Value.absent(),
    this.price = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuoteCacheTableCompanion.insert({
    required String productCode,
    this.productName = const Value.absent(),
    this.price = const Value.absent(),
    required int fetchedAt,
    required String source,
    this.rowid = const Value.absent(),
  }) : productCode = Value(productCode),
       fetchedAt = Value(fetchedAt),
       source = Value(source);
  static Insertable<QuoteCacheTableData> custom({
    Expression<String>? productCode,
    Expression<String>? productName,
    Expression<String>? price,
    Expression<int>? fetchedAt,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (productCode != null) 'product_code': productCode,
      if (productName != null) 'product_name': productName,
      if (price != null) 'price': price,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuoteCacheTableCompanion copyWith({
    Value<String>? productCode,
    Value<String?>? productName,
    Value<String?>? price,
    Value<int>? fetchedAt,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return QuoteCacheTableCompanion(
      productCode: productCode ?? this.productCode,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (productCode.present) {
      map['product_code'] = Variable<String>(productCode.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (price.present) {
      map['price'] = Variable<String>(price.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuoteCacheTableCompanion(')
          ..write('productCode: $productCode, ')
          ..write('productName: $productName, ')
          ..write('price: $price, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClassificationRuleTableTable extends ClassificationRuleTable
    with TableInfo<$ClassificationRuleTableTable, ClassificationRuleTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClassificationRuleTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
    'pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instrumentTypeMeta = const VerificationMeta(
    'instrumentType',
  );
  @override
  late final GeneratedColumn<String> instrumentType = GeneratedColumn<String>(
    'instrument_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assetClassMeta = const VerificationMeta(
    'assetClass',
  );
  @override
  late final GeneratedColumn<String> assetClass = GeneratedColumn<String>(
    'asset_class',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pattern,
    instrumentType,
    assetClass,
    priority,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'classification_rule';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClassificationRuleTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('instrument_type')) {
      context.handle(
        _instrumentTypeMeta,
        instrumentType.isAcceptableOrUnknown(
          data['instrument_type']!,
          _instrumentTypeMeta,
        ),
      );
    }
    if (data.containsKey('asset_class')) {
      context.handle(
        _assetClassMeta,
        assetClass.isAcceptableOrUnknown(data['asset_class']!, _assetClassMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClassificationRuleTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClassificationRuleTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern'],
      )!,
      instrumentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_type'],
      ),
      assetClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_class'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ClassificationRuleTableTable createAlias(String alias) {
    return $ClassificationRuleTableTable(attachedDatabase, alias);
  }
}

class ClassificationRuleTableData extends DataClass
    implements Insertable<ClassificationRuleTableData> {
  final String id;
  final String pattern;
  final String? instrumentType;
  final String? assetClass;
  final int priority;
  final int createdAt;
  const ClassificationRuleTableData({
    required this.id,
    required this.pattern,
    this.instrumentType,
    this.assetClass,
    required this.priority,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pattern'] = Variable<String>(pattern);
    if (!nullToAbsent || instrumentType != null) {
      map['instrument_type'] = Variable<String>(instrumentType);
    }
    if (!nullToAbsent || assetClass != null) {
      map['asset_class'] = Variable<String>(assetClass);
    }
    map['priority'] = Variable<int>(priority);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ClassificationRuleTableCompanion toCompanion(bool nullToAbsent) {
    return ClassificationRuleTableCompanion(
      id: Value(id),
      pattern: Value(pattern),
      instrumentType: instrumentType == null && nullToAbsent
          ? const Value.absent()
          : Value(instrumentType),
      assetClass: assetClass == null && nullToAbsent
          ? const Value.absent()
          : Value(assetClass),
      priority: Value(priority),
      createdAt: Value(createdAt),
    );
  }

  factory ClassificationRuleTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClassificationRuleTableData(
      id: serializer.fromJson<String>(json['id']),
      pattern: serializer.fromJson<String>(json['pattern']),
      instrumentType: serializer.fromJson<String?>(json['instrumentType']),
      assetClass: serializer.fromJson<String?>(json['assetClass']),
      priority: serializer.fromJson<int>(json['priority']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pattern': serializer.toJson<String>(pattern),
      'instrumentType': serializer.toJson<String?>(instrumentType),
      'assetClass': serializer.toJson<String?>(assetClass),
      'priority': serializer.toJson<int>(priority),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ClassificationRuleTableData copyWith({
    String? id,
    String? pattern,
    Value<String?> instrumentType = const Value.absent(),
    Value<String?> assetClass = const Value.absent(),
    int? priority,
    int? createdAt,
  }) => ClassificationRuleTableData(
    id: id ?? this.id,
    pattern: pattern ?? this.pattern,
    instrumentType: instrumentType.present
        ? instrumentType.value
        : this.instrumentType,
    assetClass: assetClass.present ? assetClass.value : this.assetClass,
    priority: priority ?? this.priority,
    createdAt: createdAt ?? this.createdAt,
  );
  ClassificationRuleTableData copyWithCompanion(
    ClassificationRuleTableCompanion data,
  ) {
    return ClassificationRuleTableData(
      id: data.id.present ? data.id.value : this.id,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      instrumentType: data.instrumentType.present
          ? data.instrumentType.value
          : this.instrumentType,
      assetClass: data.assetClass.present
          ? data.assetClass.value
          : this.assetClass,
      priority: data.priority.present ? data.priority.value : this.priority,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationRuleTableData(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('instrumentType: $instrumentType, ')
          ..write('assetClass: $assetClass, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, pattern, instrumentType, assetClass, priority, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClassificationRuleTableData &&
          other.id == this.id &&
          other.pattern == this.pattern &&
          other.instrumentType == this.instrumentType &&
          other.assetClass == this.assetClass &&
          other.priority == this.priority &&
          other.createdAt == this.createdAt);
}

class ClassificationRuleTableCompanion
    extends UpdateCompanion<ClassificationRuleTableData> {
  final Value<String> id;
  final Value<String> pattern;
  final Value<String?> instrumentType;
  final Value<String?> assetClass;
  final Value<int> priority;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ClassificationRuleTableCompanion({
    this.id = const Value.absent(),
    this.pattern = const Value.absent(),
    this.instrumentType = const Value.absent(),
    this.assetClass = const Value.absent(),
    this.priority = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClassificationRuleTableCompanion.insert({
    required String id,
    required String pattern,
    this.instrumentType = const Value.absent(),
    this.assetClass = const Value.absent(),
    required int priority,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       pattern = Value(pattern),
       priority = Value(priority),
       createdAt = Value(createdAt);
  static Insertable<ClassificationRuleTableData> custom({
    Expression<String>? id,
    Expression<String>? pattern,
    Expression<String>? instrumentType,
    Expression<String>? assetClass,
    Expression<int>? priority,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pattern != null) 'pattern': pattern,
      if (instrumentType != null) 'instrument_type': instrumentType,
      if (assetClass != null) 'asset_class': assetClass,
      if (priority != null) 'priority': priority,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClassificationRuleTableCompanion copyWith({
    Value<String>? id,
    Value<String>? pattern,
    Value<String?>? instrumentType,
    Value<String?>? assetClass,
    Value<int>? priority,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ClassificationRuleTableCompanion(
      id: id ?? this.id,
      pattern: pattern ?? this.pattern,
      instrumentType: instrumentType ?? this.instrumentType,
      assetClass: assetClass ?? this.assetClass,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (instrumentType.present) {
      map['instrument_type'] = Variable<String>(instrumentType.value);
    }
    if (assetClass.present) {
      map['asset_class'] = Variable<String>(assetClass.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationRuleTableCompanion(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('instrumentType: $instrumentType, ')
          ..write('assetClass: $assetClass, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingTableTable extends AppSettingTable
    with TableInfo<$AppSettingTableTable, AppSettingTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_setting';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingTableData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingTableTable createAlias(String alias) {
    return $AppSettingTableTable(attachedDatabase, alias);
  }
}

class AppSettingTableData extends DataClass
    implements Insertable<AppSettingTableData> {
  final String key;
  final String value;
  final int updatedAt;
  const AppSettingTableData({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AppSettingTableCompanion toCompanion(bool nullToAbsent) {
    return AppSettingTableCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSettingTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingTableData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AppSettingTableData copyWith({String? key, String? value, int? updatedAt}) =>
      AppSettingTableData(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSettingTableData copyWithCompanion(AppSettingTableCompanion data) {
    return AppSettingTableData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingTableData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingTableData &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingTableCompanion extends UpdateCompanion<AppSettingTableData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AppSettingTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingTableCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<AppSettingTableData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingTableCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HoldingTableTable holdingTable = $HoldingTableTable(this);
  late final $SnapshotTableTable snapshotTable = $SnapshotTableTable(this);
  late final $SnapshotHoldingTableTable snapshotHoldingTable =
      $SnapshotHoldingTableTable(this);
  late final $ImportBatchTableTable importBatchTable = $ImportBatchTableTable(
    this,
  );
  late final $DraftHoldingTableTable draftHoldingTable =
      $DraftHoldingTableTable(this);
  late final $DataIssueTableTable dataIssueTable = $DataIssueTableTable(this);
  late final $QuoteCacheTableTable quoteCacheTable = $QuoteCacheTableTable(
    this,
  );
  late final $ClassificationRuleTableTable classificationRuleTable =
      $ClassificationRuleTableTable(this);
  late final $AppSettingTableTable appSettingTable = $AppSettingTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    holdingTable,
    snapshotTable,
    snapshotHoldingTable,
    importBatchTable,
    draftHoldingTable,
    dataIssueTable,
    quoteCacheTable,
    classificationRuleTable,
    appSettingTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'snapshot',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('snapshot_holding', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$HoldingTableTableCreateCompanionBuilder =
    HoldingTableCompanion Function({
      required String id,
      required String sourcePlatform,
      required String instrumentType,
      required String assetClass,
      required String productName,
      Value<String?> productCode,
      required String currency,
      Value<String?> quantity,
      Value<String?> availableQuantity,
      Value<String?> currentPrice,
      Value<String?> costPrice,
      required String currentValue,
      Value<String?> costAmount,
      Value<String?> holdingProfit,
      Value<String?> holdingReturn,
      Value<String?> dailyProfit,
      Value<String?> cumulativeProfit,
      Value<String> platformTags,
      required String valuationMethod,
      Value<int?> valuationDate,
      required String dataOrigin,
      Value<String> fieldProvenance,
      Value<String?> note,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$HoldingTableTableUpdateCompanionBuilder =
    HoldingTableCompanion Function({
      Value<String> id,
      Value<String> sourcePlatform,
      Value<String> instrumentType,
      Value<String> assetClass,
      Value<String> productName,
      Value<String?> productCode,
      Value<String> currency,
      Value<String?> quantity,
      Value<String?> availableQuantity,
      Value<String?> currentPrice,
      Value<String?> costPrice,
      Value<String> currentValue,
      Value<String?> costAmount,
      Value<String?> holdingProfit,
      Value<String?> holdingReturn,
      Value<String?> dailyProfit,
      Value<String?> cumulativeProfit,
      Value<String> platformTags,
      Value<String> valuationMethod,
      Value<int?> valuationDate,
      Value<String> dataOrigin,
      Value<String> fieldProvenance,
      Value<String?> note,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$HoldingTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $HoldingTableTable, HoldingTableData> {
  $$HoldingTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DataIssueTableTable, List<DataIssueTableData>>
  _dataIssueTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dataIssueTable,
    aliasName: 'holding__id__data_issue__holding_id',
  );

  $$DataIssueTableTableProcessedTableManager get dataIssueTableRefs {
    final manager = $$DataIssueTableTableTableManager(
      $_db,
      $_db.dataIssueTable,
    ).filter((f) => f.holdingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dataIssueTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$HoldingTableTableFilterComposer
    extends Composer<_$AppDatabase, $HoldingTableTable> {
  $$HoldingTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePlatform => $composableBuilder(
    column: $table.sourcePlatform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instrumentType => $composableBuilder(
    column: $table.instrumentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productCode => $composableBuilder(
    column: $table.productCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availableQuantity => $composableBuilder(
    column: $table.availableQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentPrice => $composableBuilder(
    column: $table.currentPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get costAmount => $composableBuilder(
    column: $table.costAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get holdingProfit => $composableBuilder(
    column: $table.holdingProfit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get holdingReturn => $composableBuilder(
    column: $table.holdingReturn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dailyProfit => $composableBuilder(
    column: $table.dailyProfit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cumulativeProfit => $composableBuilder(
    column: $table.cumulativeProfit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platformTags => $composableBuilder(
    column: $table.platformTags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valuationMethod => $composableBuilder(
    column: $table.valuationMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get valuationDate => $composableBuilder(
    column: $table.valuationDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataOrigin => $composableBuilder(
    column: $table.dataOrigin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldProvenance => $composableBuilder(
    column: $table.fieldProvenance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> dataIssueTableRefs(
    Expression<bool> Function($$DataIssueTableTableFilterComposer f) f,
  ) {
    final $$DataIssueTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dataIssueTable,
      getReferencedColumn: (t) => t.holdingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DataIssueTableTableFilterComposer(
            $db: $db,
            $table: $db.dataIssueTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HoldingTableTableOrderingComposer
    extends Composer<_$AppDatabase, $HoldingTableTable> {
  $$HoldingTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePlatform => $composableBuilder(
    column: $table.sourcePlatform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instrumentType => $composableBuilder(
    column: $table.instrumentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productCode => $composableBuilder(
    column: $table.productCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availableQuantity => $composableBuilder(
    column: $table.availableQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentPrice => $composableBuilder(
    column: $table.currentPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get costAmount => $composableBuilder(
    column: $table.costAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holdingProfit => $composableBuilder(
    column: $table.holdingProfit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holdingReturn => $composableBuilder(
    column: $table.holdingReturn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dailyProfit => $composableBuilder(
    column: $table.dailyProfit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cumulativeProfit => $composableBuilder(
    column: $table.cumulativeProfit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platformTags => $composableBuilder(
    column: $table.platformTags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valuationMethod => $composableBuilder(
    column: $table.valuationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get valuationDate => $composableBuilder(
    column: $table.valuationDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataOrigin => $composableBuilder(
    column: $table.dataOrigin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldProvenance => $composableBuilder(
    column: $table.fieldProvenance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HoldingTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $HoldingTableTable> {
  $$HoldingTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourcePlatform => $composableBuilder(
    column: $table.sourcePlatform,
    builder: (column) => column,
  );

  GeneratedColumn<String> get instrumentType => $composableBuilder(
    column: $table.instrumentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productCode => $composableBuilder(
    column: $table.productCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get availableQuantity => $composableBuilder(
    column: $table.availableQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentPrice => $composableBuilder(
    column: $table.currentPrice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get costPrice =>
      $composableBuilder(column: $table.costPrice, builder: (column) => column);

  GeneratedColumn<String> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get costAmount => $composableBuilder(
    column: $table.costAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get holdingProfit => $composableBuilder(
    column: $table.holdingProfit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get holdingReturn => $composableBuilder(
    column: $table.holdingReturn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dailyProfit => $composableBuilder(
    column: $table.dailyProfit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cumulativeProfit => $composableBuilder(
    column: $table.cumulativeProfit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get platformTags => $composableBuilder(
    column: $table.platformTags,
    builder: (column) => column,
  );

  GeneratedColumn<String> get valuationMethod => $composableBuilder(
    column: $table.valuationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get valuationDate => $composableBuilder(
    column: $table.valuationDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataOrigin => $composableBuilder(
    column: $table.dataOrigin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fieldProvenance => $composableBuilder(
    column: $table.fieldProvenance,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> dataIssueTableRefs<T extends Object>(
    Expression<T> Function($$DataIssueTableTableAnnotationComposer a) f,
  ) {
    final $$DataIssueTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dataIssueTable,
      getReferencedColumn: (t) => t.holdingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DataIssueTableTableAnnotationComposer(
            $db: $db,
            $table: $db.dataIssueTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HoldingTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HoldingTableTable,
          HoldingTableData,
          $$HoldingTableTableFilterComposer,
          $$HoldingTableTableOrderingComposer,
          $$HoldingTableTableAnnotationComposer,
          $$HoldingTableTableCreateCompanionBuilder,
          $$HoldingTableTableUpdateCompanionBuilder,
          (HoldingTableData, $$HoldingTableTableReferences),
          HoldingTableData,
          PrefetchHooks Function({bool dataIssueTableRefs})
        > {
  $$HoldingTableTableTableManager(_$AppDatabase db, $HoldingTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HoldingTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HoldingTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HoldingTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourcePlatform = const Value.absent(),
                Value<String> instrumentType = const Value.absent(),
                Value<String> assetClass = const Value.absent(),
                Value<String> productName = const Value.absent(),
                Value<String?> productCode = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> quantity = const Value.absent(),
                Value<String?> availableQuantity = const Value.absent(),
                Value<String?> currentPrice = const Value.absent(),
                Value<String?> costPrice = const Value.absent(),
                Value<String> currentValue = const Value.absent(),
                Value<String?> costAmount = const Value.absent(),
                Value<String?> holdingProfit = const Value.absent(),
                Value<String?> holdingReturn = const Value.absent(),
                Value<String?> dailyProfit = const Value.absent(),
                Value<String?> cumulativeProfit = const Value.absent(),
                Value<String> platformTags = const Value.absent(),
                Value<String> valuationMethod = const Value.absent(),
                Value<int?> valuationDate = const Value.absent(),
                Value<String> dataOrigin = const Value.absent(),
                Value<String> fieldProvenance = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HoldingTableCompanion(
                id: id,
                sourcePlatform: sourcePlatform,
                instrumentType: instrumentType,
                assetClass: assetClass,
                productName: productName,
                productCode: productCode,
                currency: currency,
                quantity: quantity,
                availableQuantity: availableQuantity,
                currentPrice: currentPrice,
                costPrice: costPrice,
                currentValue: currentValue,
                costAmount: costAmount,
                holdingProfit: holdingProfit,
                holdingReturn: holdingReturn,
                dailyProfit: dailyProfit,
                cumulativeProfit: cumulativeProfit,
                platformTags: platformTags,
                valuationMethod: valuationMethod,
                valuationDate: valuationDate,
                dataOrigin: dataOrigin,
                fieldProvenance: fieldProvenance,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourcePlatform,
                required String instrumentType,
                required String assetClass,
                required String productName,
                Value<String?> productCode = const Value.absent(),
                required String currency,
                Value<String?> quantity = const Value.absent(),
                Value<String?> availableQuantity = const Value.absent(),
                Value<String?> currentPrice = const Value.absent(),
                Value<String?> costPrice = const Value.absent(),
                required String currentValue,
                Value<String?> costAmount = const Value.absent(),
                Value<String?> holdingProfit = const Value.absent(),
                Value<String?> holdingReturn = const Value.absent(),
                Value<String?> dailyProfit = const Value.absent(),
                Value<String?> cumulativeProfit = const Value.absent(),
                Value<String> platformTags = const Value.absent(),
                required String valuationMethod,
                Value<int?> valuationDate = const Value.absent(),
                required String dataOrigin,
                Value<String> fieldProvenance = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => HoldingTableCompanion.insert(
                id: id,
                sourcePlatform: sourcePlatform,
                instrumentType: instrumentType,
                assetClass: assetClass,
                productName: productName,
                productCode: productCode,
                currency: currency,
                quantity: quantity,
                availableQuantity: availableQuantity,
                currentPrice: currentPrice,
                costPrice: costPrice,
                currentValue: currentValue,
                costAmount: costAmount,
                holdingProfit: holdingProfit,
                holdingReturn: holdingReturn,
                dailyProfit: dailyProfit,
                cumulativeProfit: cumulativeProfit,
                platformTags: platformTags,
                valuationMethod: valuationMethod,
                valuationDate: valuationDate,
                dataOrigin: dataOrigin,
                fieldProvenance: fieldProvenance,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HoldingTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({dataIssueTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (dataIssueTableRefs) db.dataIssueTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (dataIssueTableRefs)
                    await $_getPrefetchedData<
                      HoldingTableData,
                      $HoldingTableTable,
                      DataIssueTableData
                    >(
                      currentTable: table,
                      referencedTable: $$HoldingTableTableReferences
                          ._dataIssueTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$HoldingTableTableReferences(
                            db,
                            table,
                            p0,
                          ).dataIssueTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.holdingId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$HoldingTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HoldingTableTable,
      HoldingTableData,
      $$HoldingTableTableFilterComposer,
      $$HoldingTableTableOrderingComposer,
      $$HoldingTableTableAnnotationComposer,
      $$HoldingTableTableCreateCompanionBuilder,
      $$HoldingTableTableUpdateCompanionBuilder,
      (HoldingTableData, $$HoldingTableTableReferences),
      HoldingTableData,
      PrefetchHooks Function({bool dataIssueTableRefs})
    >;
typedef $$SnapshotTableTableCreateCompanionBuilder =
    SnapshotTableCompanion Function({
      required String id,
      required String label,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$SnapshotTableTableUpdateCompanionBuilder =
    SnapshotTableCompanion Function({
      Value<String> id,
      Value<String> label,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$SnapshotTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $SnapshotTableTable, SnapshotTableData> {
  $$SnapshotTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $SnapshotHoldingTableTable,
    List<SnapshotHoldingTableData>
  >
  _snapshotHoldingTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.snapshotHoldingTable,
        aliasName: 'snapshot__id__snapshot_holding__snapshot_id',
      );

  $$SnapshotHoldingTableTableProcessedTableManager
  get snapshotHoldingTableRefs {
    final manager = $$SnapshotHoldingTableTableTableManager(
      $_db,
      $_db.snapshotHoldingTable,
    ).filter((f) => f.snapshotId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _snapshotHoldingTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SnapshotTableTableFilterComposer
    extends Composer<_$AppDatabase, $SnapshotTableTable> {
  $$SnapshotTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> snapshotHoldingTableRefs(
    Expression<bool> Function($$SnapshotHoldingTableTableFilterComposer f) f,
  ) {
    final $$SnapshotHoldingTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snapshotHoldingTable,
      getReferencedColumn: (t) => t.snapshotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotHoldingTableTableFilterComposer(
            $db: $db,
            $table: $db.snapshotHoldingTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SnapshotTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SnapshotTableTable> {
  $$SnapshotTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SnapshotTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SnapshotTableTable> {
  $$SnapshotTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> snapshotHoldingTableRefs<T extends Object>(
    Expression<T> Function($$SnapshotHoldingTableTableAnnotationComposer a) f,
  ) {
    final $$SnapshotHoldingTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.snapshotHoldingTable,
          getReferencedColumn: (t) => t.snapshotId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SnapshotHoldingTableTableAnnotationComposer(
                $db: $db,
                $table: $db.snapshotHoldingTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SnapshotTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SnapshotTableTable,
          SnapshotTableData,
          $$SnapshotTableTableFilterComposer,
          $$SnapshotTableTableOrderingComposer,
          $$SnapshotTableTableAnnotationComposer,
          $$SnapshotTableTableCreateCompanionBuilder,
          $$SnapshotTableTableUpdateCompanionBuilder,
          (SnapshotTableData, $$SnapshotTableTableReferences),
          SnapshotTableData,
          PrefetchHooks Function({bool snapshotHoldingTableRefs})
        > {
  $$SnapshotTableTableTableManager(_$AppDatabase db, $SnapshotTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnapshotTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnapshotTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnapshotTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SnapshotTableCompanion(
                id: id,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String label,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SnapshotTableCompanion.insert(
                id: id,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SnapshotTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({snapshotHoldingTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (snapshotHoldingTableRefs) db.snapshotHoldingTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (snapshotHoldingTableRefs)
                    await $_getPrefetchedData<
                      SnapshotTableData,
                      $SnapshotTableTable,
                      SnapshotHoldingTableData
                    >(
                      currentTable: table,
                      referencedTable: $$SnapshotTableTableReferences
                          ._snapshotHoldingTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SnapshotTableTableReferences(
                            db,
                            table,
                            p0,
                          ).snapshotHoldingTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.snapshotId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SnapshotTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SnapshotTableTable,
      SnapshotTableData,
      $$SnapshotTableTableFilterComposer,
      $$SnapshotTableTableOrderingComposer,
      $$SnapshotTableTableAnnotationComposer,
      $$SnapshotTableTableCreateCompanionBuilder,
      $$SnapshotTableTableUpdateCompanionBuilder,
      (SnapshotTableData, $$SnapshotTableTableReferences),
      SnapshotTableData,
      PrefetchHooks Function({bool snapshotHoldingTableRefs})
    >;
typedef $$SnapshotHoldingTableTableCreateCompanionBuilder =
    SnapshotHoldingTableCompanion Function({
      Value<int> id,
      required String snapshotId,
      required String holdingId,
      required String sourcePlatform,
      required String instrumentType,
      required String assetClass,
      required String productName,
      Value<String?> productCode,
      required String currency,
      Value<String?> quantity,
      Value<String?> currentPrice,
      required String currentValue,
      Value<String?> costAmount,
      Value<String?> holdingProfit,
      Value<String?> dailyProfit,
      Value<String?> cumulativeProfit,
      Value<int?> valuationDate,
      Value<String> fieldProvenance,
    });
typedef $$SnapshotHoldingTableTableUpdateCompanionBuilder =
    SnapshotHoldingTableCompanion Function({
      Value<int> id,
      Value<String> snapshotId,
      Value<String> holdingId,
      Value<String> sourcePlatform,
      Value<String> instrumentType,
      Value<String> assetClass,
      Value<String> productName,
      Value<String?> productCode,
      Value<String> currency,
      Value<String?> quantity,
      Value<String?> currentPrice,
      Value<String> currentValue,
      Value<String?> costAmount,
      Value<String?> holdingProfit,
      Value<String?> dailyProfit,
      Value<String?> cumulativeProfit,
      Value<int?> valuationDate,
      Value<String> fieldProvenance,
    });

final class $$SnapshotHoldingTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SnapshotHoldingTableTable,
          SnapshotHoldingTableData
        > {
  $$SnapshotHoldingTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SnapshotTableTable _snapshotIdTable(_$AppDatabase db) => db
      .snapshotTable
      .createAlias('snapshot_holding__snapshot_id__snapshot__id');

  $$SnapshotTableTableProcessedTableManager get snapshotId {
    final $_column = $_itemColumn<String>('snapshot_id')!;

    final manager = $$SnapshotTableTableTableManager(
      $_db,
      $_db.snapshotTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_snapshotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SnapshotHoldingTableTableFilterComposer
    extends Composer<_$AppDatabase, $SnapshotHoldingTableTable> {
  $$SnapshotHoldingTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get holdingId => $composableBuilder(
    column: $table.holdingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePlatform => $composableBuilder(
    column: $table.sourcePlatform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instrumentType => $composableBuilder(
    column: $table.instrumentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productCode => $composableBuilder(
    column: $table.productCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentPrice => $composableBuilder(
    column: $table.currentPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get costAmount => $composableBuilder(
    column: $table.costAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get holdingProfit => $composableBuilder(
    column: $table.holdingProfit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dailyProfit => $composableBuilder(
    column: $table.dailyProfit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cumulativeProfit => $composableBuilder(
    column: $table.cumulativeProfit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get valuationDate => $composableBuilder(
    column: $table.valuationDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldProvenance => $composableBuilder(
    column: $table.fieldProvenance,
    builder: (column) => ColumnFilters(column),
  );

  $$SnapshotTableTableFilterComposer get snapshotId {
    final $$SnapshotTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotId,
      referencedTable: $db.snapshotTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotTableTableFilterComposer(
            $db: $db,
            $table: $db.snapshotTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnapshotHoldingTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SnapshotHoldingTableTable> {
  $$SnapshotHoldingTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holdingId => $composableBuilder(
    column: $table.holdingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePlatform => $composableBuilder(
    column: $table.sourcePlatform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instrumentType => $composableBuilder(
    column: $table.instrumentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productCode => $composableBuilder(
    column: $table.productCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentPrice => $composableBuilder(
    column: $table.currentPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get costAmount => $composableBuilder(
    column: $table.costAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holdingProfit => $composableBuilder(
    column: $table.holdingProfit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dailyProfit => $composableBuilder(
    column: $table.dailyProfit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cumulativeProfit => $composableBuilder(
    column: $table.cumulativeProfit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get valuationDate => $composableBuilder(
    column: $table.valuationDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldProvenance => $composableBuilder(
    column: $table.fieldProvenance,
    builder: (column) => ColumnOrderings(column),
  );

  $$SnapshotTableTableOrderingComposer get snapshotId {
    final $$SnapshotTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotId,
      referencedTable: $db.snapshotTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotTableTableOrderingComposer(
            $db: $db,
            $table: $db.snapshotTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnapshotHoldingTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SnapshotHoldingTableTable> {
  $$SnapshotHoldingTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get holdingId =>
      $composableBuilder(column: $table.holdingId, builder: (column) => column);

  GeneratedColumn<String> get sourcePlatform => $composableBuilder(
    column: $table.sourcePlatform,
    builder: (column) => column,
  );

  GeneratedColumn<String> get instrumentType => $composableBuilder(
    column: $table.instrumentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productCode => $composableBuilder(
    column: $table.productCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get currentPrice => $composableBuilder(
    column: $table.currentPrice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get costAmount => $composableBuilder(
    column: $table.costAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get holdingProfit => $composableBuilder(
    column: $table.holdingProfit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dailyProfit => $composableBuilder(
    column: $table.dailyProfit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cumulativeProfit => $composableBuilder(
    column: $table.cumulativeProfit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get valuationDate => $composableBuilder(
    column: $table.valuationDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fieldProvenance => $composableBuilder(
    column: $table.fieldProvenance,
    builder: (column) => column,
  );

  $$SnapshotTableTableAnnotationComposer get snapshotId {
    final $$SnapshotTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotId,
      referencedTable: $db.snapshotTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotTableTableAnnotationComposer(
            $db: $db,
            $table: $db.snapshotTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnapshotHoldingTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SnapshotHoldingTableTable,
          SnapshotHoldingTableData,
          $$SnapshotHoldingTableTableFilterComposer,
          $$SnapshotHoldingTableTableOrderingComposer,
          $$SnapshotHoldingTableTableAnnotationComposer,
          $$SnapshotHoldingTableTableCreateCompanionBuilder,
          $$SnapshotHoldingTableTableUpdateCompanionBuilder,
          (SnapshotHoldingTableData, $$SnapshotHoldingTableTableReferences),
          SnapshotHoldingTableData,
          PrefetchHooks Function({bool snapshotId})
        > {
  $$SnapshotHoldingTableTableTableManager(
    _$AppDatabase db,
    $SnapshotHoldingTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnapshotHoldingTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnapshotHoldingTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SnapshotHoldingTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> snapshotId = const Value.absent(),
                Value<String> holdingId = const Value.absent(),
                Value<String> sourcePlatform = const Value.absent(),
                Value<String> instrumentType = const Value.absent(),
                Value<String> assetClass = const Value.absent(),
                Value<String> productName = const Value.absent(),
                Value<String?> productCode = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> quantity = const Value.absent(),
                Value<String?> currentPrice = const Value.absent(),
                Value<String> currentValue = const Value.absent(),
                Value<String?> costAmount = const Value.absent(),
                Value<String?> holdingProfit = const Value.absent(),
                Value<String?> dailyProfit = const Value.absent(),
                Value<String?> cumulativeProfit = const Value.absent(),
                Value<int?> valuationDate = const Value.absent(),
                Value<String> fieldProvenance = const Value.absent(),
              }) => SnapshotHoldingTableCompanion(
                id: id,
                snapshotId: snapshotId,
                holdingId: holdingId,
                sourcePlatform: sourcePlatform,
                instrumentType: instrumentType,
                assetClass: assetClass,
                productName: productName,
                productCode: productCode,
                currency: currency,
                quantity: quantity,
                currentPrice: currentPrice,
                currentValue: currentValue,
                costAmount: costAmount,
                holdingProfit: holdingProfit,
                dailyProfit: dailyProfit,
                cumulativeProfit: cumulativeProfit,
                valuationDate: valuationDate,
                fieldProvenance: fieldProvenance,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String snapshotId,
                required String holdingId,
                required String sourcePlatform,
                required String instrumentType,
                required String assetClass,
                required String productName,
                Value<String?> productCode = const Value.absent(),
                required String currency,
                Value<String?> quantity = const Value.absent(),
                Value<String?> currentPrice = const Value.absent(),
                required String currentValue,
                Value<String?> costAmount = const Value.absent(),
                Value<String?> holdingProfit = const Value.absent(),
                Value<String?> dailyProfit = const Value.absent(),
                Value<String?> cumulativeProfit = const Value.absent(),
                Value<int?> valuationDate = const Value.absent(),
                Value<String> fieldProvenance = const Value.absent(),
              }) => SnapshotHoldingTableCompanion.insert(
                id: id,
                snapshotId: snapshotId,
                holdingId: holdingId,
                sourcePlatform: sourcePlatform,
                instrumentType: instrumentType,
                assetClass: assetClass,
                productName: productName,
                productCode: productCode,
                currency: currency,
                quantity: quantity,
                currentPrice: currentPrice,
                currentValue: currentValue,
                costAmount: costAmount,
                holdingProfit: holdingProfit,
                dailyProfit: dailyProfit,
                cumulativeProfit: cumulativeProfit,
                valuationDate: valuationDate,
                fieldProvenance: fieldProvenance,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SnapshotHoldingTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({snapshotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (snapshotId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.snapshotId,
                                referencedTable:
                                    $$SnapshotHoldingTableTableReferences
                                        ._snapshotIdTable(db),
                                referencedColumn:
                                    $$SnapshotHoldingTableTableReferences
                                        ._snapshotIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SnapshotHoldingTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SnapshotHoldingTableTable,
      SnapshotHoldingTableData,
      $$SnapshotHoldingTableTableFilterComposer,
      $$SnapshotHoldingTableTableOrderingComposer,
      $$SnapshotHoldingTableTableAnnotationComposer,
      $$SnapshotHoldingTableTableCreateCompanionBuilder,
      $$SnapshotHoldingTableTableUpdateCompanionBuilder,
      (SnapshotHoldingTableData, $$SnapshotHoldingTableTableReferences),
      SnapshotHoldingTableData,
      PrefetchHooks Function({bool snapshotId})
    >;
typedef $$ImportBatchTableTableCreateCompanionBuilder =
    ImportBatchTableCompanion Function({
      required String id,
      required String sourcePlatform,
      required int importedAt,
      Value<String?> rawDataHash,
      required String status,
      Value<int> rowid,
    });
typedef $$ImportBatchTableTableUpdateCompanionBuilder =
    ImportBatchTableCompanion Function({
      Value<String> id,
      Value<String> sourcePlatform,
      Value<int> importedAt,
      Value<String?> rawDataHash,
      Value<String> status,
      Value<int> rowid,
    });

final class $$ImportBatchTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ImportBatchTableTable,
          ImportBatchTableData
        > {
  $$ImportBatchTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $DraftHoldingTableTable,
    List<DraftHoldingTableData>
  >
  _draftHoldingTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.draftHoldingTable,
        aliasName: 'import_batch__id__draft_holding__import_batch_id',
      );

  $$DraftHoldingTableTableProcessedTableManager get draftHoldingTableRefs {
    final manager = $$DraftHoldingTableTableTableManager(
      $_db,
      $_db.draftHoldingTable,
    ).filter((f) => f.importBatchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _draftHoldingTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ImportBatchTableTableFilterComposer
    extends Composer<_$AppDatabase, $ImportBatchTableTable> {
  $$ImportBatchTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePlatform => $composableBuilder(
    column: $table.sourcePlatform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawDataHash => $composableBuilder(
    column: $table.rawDataHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> draftHoldingTableRefs(
    Expression<bool> Function($$DraftHoldingTableTableFilterComposer f) f,
  ) {
    final $$DraftHoldingTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.draftHoldingTable,
      getReferencedColumn: (t) => t.importBatchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftHoldingTableTableFilterComposer(
            $db: $db,
            $table: $db.draftHoldingTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImportBatchTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportBatchTableTable> {
  $$ImportBatchTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePlatform => $composableBuilder(
    column: $table.sourcePlatform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawDataHash => $composableBuilder(
    column: $table.rawDataHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportBatchTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportBatchTableTable> {
  $$ImportBatchTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourcePlatform => $composableBuilder(
    column: $table.sourcePlatform,
    builder: (column) => column,
  );

  GeneratedColumn<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawDataHash => $composableBuilder(
    column: $table.rawDataHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  Expression<T> draftHoldingTableRefs<T extends Object>(
    Expression<T> Function($$DraftHoldingTableTableAnnotationComposer a) f,
  ) {
    final $$DraftHoldingTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.draftHoldingTable,
          getReferencedColumn: (t) => t.importBatchId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DraftHoldingTableTableAnnotationComposer(
                $db: $db,
                $table: $db.draftHoldingTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ImportBatchTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportBatchTableTable,
          ImportBatchTableData,
          $$ImportBatchTableTableFilterComposer,
          $$ImportBatchTableTableOrderingComposer,
          $$ImportBatchTableTableAnnotationComposer,
          $$ImportBatchTableTableCreateCompanionBuilder,
          $$ImportBatchTableTableUpdateCompanionBuilder,
          (ImportBatchTableData, $$ImportBatchTableTableReferences),
          ImportBatchTableData,
          PrefetchHooks Function({bool draftHoldingTableRefs})
        > {
  $$ImportBatchTableTableTableManager(
    _$AppDatabase db,
    $ImportBatchTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportBatchTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportBatchTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportBatchTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourcePlatform = const Value.absent(),
                Value<int> importedAt = const Value.absent(),
                Value<String?> rawDataHash = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportBatchTableCompanion(
                id: id,
                sourcePlatform: sourcePlatform,
                importedAt: importedAt,
                rawDataHash: rawDataHash,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourcePlatform,
                required int importedAt,
                Value<String?> rawDataHash = const Value.absent(),
                required String status,
                Value<int> rowid = const Value.absent(),
              }) => ImportBatchTableCompanion.insert(
                id: id,
                sourcePlatform: sourcePlatform,
                importedAt: importedAt,
                rawDataHash: rawDataHash,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ImportBatchTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({draftHoldingTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (draftHoldingTableRefs) db.draftHoldingTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (draftHoldingTableRefs)
                    await $_getPrefetchedData<
                      ImportBatchTableData,
                      $ImportBatchTableTable,
                      DraftHoldingTableData
                    >(
                      currentTable: table,
                      referencedTable: $$ImportBatchTableTableReferences
                          ._draftHoldingTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ImportBatchTableTableReferences(
                            db,
                            table,
                            p0,
                          ).draftHoldingTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.importBatchId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ImportBatchTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportBatchTableTable,
      ImportBatchTableData,
      $$ImportBatchTableTableFilterComposer,
      $$ImportBatchTableTableOrderingComposer,
      $$ImportBatchTableTableAnnotationComposer,
      $$ImportBatchTableTableCreateCompanionBuilder,
      $$ImportBatchTableTableUpdateCompanionBuilder,
      (ImportBatchTableData, $$ImportBatchTableTableReferences),
      ImportBatchTableData,
      PrefetchHooks Function({bool draftHoldingTableRefs})
    >;
typedef $$DraftHoldingTableTableCreateCompanionBuilder =
    DraftHoldingTableCompanion Function({
      required String id,
      Value<String?> importBatchId,
      required String rawJson,
      required String status,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$DraftHoldingTableTableUpdateCompanionBuilder =
    DraftHoldingTableCompanion Function({
      Value<String> id,
      Value<String?> importBatchId,
      Value<String> rawJson,
      Value<String> status,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$DraftHoldingTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DraftHoldingTableTable,
          DraftHoldingTableData
        > {
  $$DraftHoldingTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ImportBatchTableTable _importBatchIdTable(_$AppDatabase db) => db
      .importBatchTable
      .createAlias('draft_holding__import_batch_id__import_batch__id');

  $$ImportBatchTableTableProcessedTableManager? get importBatchId {
    final $_column = $_itemColumn<String>('import_batch_id');
    if ($_column == null) return null;
    final manager = $$ImportBatchTableTableTableManager(
      $_db,
      $_db.importBatchTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_importBatchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DraftHoldingTableTableFilterComposer
    extends Composer<_$AppDatabase, $DraftHoldingTableTable> {
  $$DraftHoldingTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ImportBatchTableTableFilterComposer get importBatchId {
    final $$ImportBatchTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importBatchId,
      referencedTable: $db.importBatchTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportBatchTableTableFilterComposer(
            $db: $db,
            $table: $db.importBatchTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DraftHoldingTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftHoldingTableTable> {
  $$DraftHoldingTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImportBatchTableTableOrderingComposer get importBatchId {
    final $$ImportBatchTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importBatchId,
      referencedTable: $db.importBatchTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportBatchTableTableOrderingComposer(
            $db: $db,
            $table: $db.importBatchTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DraftHoldingTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftHoldingTableTable> {
  $$DraftHoldingTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ImportBatchTableTableAnnotationComposer get importBatchId {
    final $$ImportBatchTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importBatchId,
      referencedTable: $db.importBatchTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportBatchTableTableAnnotationComposer(
            $db: $db,
            $table: $db.importBatchTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DraftHoldingTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftHoldingTableTable,
          DraftHoldingTableData,
          $$DraftHoldingTableTableFilterComposer,
          $$DraftHoldingTableTableOrderingComposer,
          $$DraftHoldingTableTableAnnotationComposer,
          $$DraftHoldingTableTableCreateCompanionBuilder,
          $$DraftHoldingTableTableUpdateCompanionBuilder,
          (DraftHoldingTableData, $$DraftHoldingTableTableReferences),
          DraftHoldingTableData,
          PrefetchHooks Function({bool importBatchId})
        > {
  $$DraftHoldingTableTableTableManager(
    _$AppDatabase db,
    $DraftHoldingTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftHoldingTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftHoldingTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftHoldingTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> importBatchId = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftHoldingTableCompanion(
                id: id,
                importBatchId: importBatchId,
                rawJson: rawJson,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> importBatchId = const Value.absent(),
                required String rawJson,
                required String status,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => DraftHoldingTableCompanion.insert(
                id: id,
                importBatchId: importBatchId,
                rawJson: rawJson,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DraftHoldingTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({importBatchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (importBatchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.importBatchId,
                                referencedTable:
                                    $$DraftHoldingTableTableReferences
                                        ._importBatchIdTable(db),
                                referencedColumn:
                                    $$DraftHoldingTableTableReferences
                                        ._importBatchIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DraftHoldingTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftHoldingTableTable,
      DraftHoldingTableData,
      $$DraftHoldingTableTableFilterComposer,
      $$DraftHoldingTableTableOrderingComposer,
      $$DraftHoldingTableTableAnnotationComposer,
      $$DraftHoldingTableTableCreateCompanionBuilder,
      $$DraftHoldingTableTableUpdateCompanionBuilder,
      (DraftHoldingTableData, $$DraftHoldingTableTableReferences),
      DraftHoldingTableData,
      PrefetchHooks Function({bool importBatchId})
    >;
typedef $$DataIssueTableTableCreateCompanionBuilder =
    DataIssueTableCompanion Function({
      required String id,
      Value<String?> holdingId,
      required String issueType,
      required String description,
      required int createdAt,
      Value<int?> resolvedAt,
      Value<int> rowid,
    });
typedef $$DataIssueTableTableUpdateCompanionBuilder =
    DataIssueTableCompanion Function({
      Value<String> id,
      Value<String?> holdingId,
      Value<String> issueType,
      Value<String> description,
      Value<int> createdAt,
      Value<int?> resolvedAt,
      Value<int> rowid,
    });

final class $$DataIssueTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DataIssueTableTable,
          DataIssueTableData
        > {
  $$DataIssueTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $HoldingTableTable _holdingIdTable(_$AppDatabase db) =>
      db.holdingTable.createAlias('data_issue__holding_id__holding__id');

  $$HoldingTableTableProcessedTableManager? get holdingId {
    final $_column = $_itemColumn<String>('holding_id');
    if ($_column == null) return null;
    final manager = $$HoldingTableTableTableManager(
      $_db,
      $_db.holdingTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_holdingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DataIssueTableTableFilterComposer
    extends Composer<_$AppDatabase, $DataIssueTableTable> {
  $$DataIssueTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issueType => $composableBuilder(
    column: $table.issueType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$HoldingTableTableFilterComposer get holdingId {
    final $$HoldingTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.holdingId,
      referencedTable: $db.holdingTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HoldingTableTableFilterComposer(
            $db: $db,
            $table: $db.holdingTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DataIssueTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DataIssueTableTable> {
  $$DataIssueTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issueType => $composableBuilder(
    column: $table.issueType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$HoldingTableTableOrderingComposer get holdingId {
    final $$HoldingTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.holdingId,
      referencedTable: $db.holdingTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HoldingTableTableOrderingComposer(
            $db: $db,
            $table: $db.holdingTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DataIssueTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DataIssueTableTable> {
  $$DataIssueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get issueType =>
      $composableBuilder(column: $table.issueType, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  $$HoldingTableTableAnnotationComposer get holdingId {
    final $$HoldingTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.holdingId,
      referencedTable: $db.holdingTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HoldingTableTableAnnotationComposer(
            $db: $db,
            $table: $db.holdingTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DataIssueTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DataIssueTableTable,
          DataIssueTableData,
          $$DataIssueTableTableFilterComposer,
          $$DataIssueTableTableOrderingComposer,
          $$DataIssueTableTableAnnotationComposer,
          $$DataIssueTableTableCreateCompanionBuilder,
          $$DataIssueTableTableUpdateCompanionBuilder,
          (DataIssueTableData, $$DataIssueTableTableReferences),
          DataIssueTableData,
          PrefetchHooks Function({bool holdingId})
        > {
  $$DataIssueTableTableTableManager(
    _$AppDatabase db,
    $DataIssueTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DataIssueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DataIssueTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DataIssueTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> holdingId = const Value.absent(),
                Value<String> issueType = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DataIssueTableCompanion(
                id: id,
                holdingId: holdingId,
                issueType: issueType,
                description: description,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> holdingId = const Value.absent(),
                required String issueType,
                required String description,
                required int createdAt,
                Value<int?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DataIssueTableCompanion.insert(
                id: id,
                holdingId: holdingId,
                issueType: issueType,
                description: description,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DataIssueTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({holdingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (holdingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.holdingId,
                                referencedTable: $$DataIssueTableTableReferences
                                    ._holdingIdTable(db),
                                referencedColumn:
                                    $$DataIssueTableTableReferences
                                        ._holdingIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DataIssueTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DataIssueTableTable,
      DataIssueTableData,
      $$DataIssueTableTableFilterComposer,
      $$DataIssueTableTableOrderingComposer,
      $$DataIssueTableTableAnnotationComposer,
      $$DataIssueTableTableCreateCompanionBuilder,
      $$DataIssueTableTableUpdateCompanionBuilder,
      (DataIssueTableData, $$DataIssueTableTableReferences),
      DataIssueTableData,
      PrefetchHooks Function({bool holdingId})
    >;
typedef $$QuoteCacheTableTableCreateCompanionBuilder =
    QuoteCacheTableCompanion Function({
      required String productCode,
      Value<String?> productName,
      Value<String?> price,
      required int fetchedAt,
      required String source,
      Value<int> rowid,
    });
typedef $$QuoteCacheTableTableUpdateCompanionBuilder =
    QuoteCacheTableCompanion Function({
      Value<String> productCode,
      Value<String?> productName,
      Value<String?> price,
      Value<int> fetchedAt,
      Value<String> source,
      Value<int> rowid,
    });

class $$QuoteCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $QuoteCacheTableTable> {
  $$QuoteCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get productCode => $composableBuilder(
    column: $table.productCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuoteCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $QuoteCacheTableTable> {
  $$QuoteCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get productCode => $composableBuilder(
    column: $table.productCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuoteCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuoteCacheTableTable> {
  $$QuoteCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get productCode => $composableBuilder(
    column: $table.productCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$QuoteCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuoteCacheTableTable,
          QuoteCacheTableData,
          $$QuoteCacheTableTableFilterComposer,
          $$QuoteCacheTableTableOrderingComposer,
          $$QuoteCacheTableTableAnnotationComposer,
          $$QuoteCacheTableTableCreateCompanionBuilder,
          $$QuoteCacheTableTableUpdateCompanionBuilder,
          (
            QuoteCacheTableData,
            BaseReferences<
              _$AppDatabase,
              $QuoteCacheTableTable,
              QuoteCacheTableData
            >,
          ),
          QuoteCacheTableData,
          PrefetchHooks Function()
        > {
  $$QuoteCacheTableTableTableManager(
    _$AppDatabase db,
    $QuoteCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuoteCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuoteCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuoteCacheTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> productCode = const Value.absent(),
                Value<String?> productName = const Value.absent(),
                Value<String?> price = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuoteCacheTableCompanion(
                productCode: productCode,
                productName: productName,
                price: price,
                fetchedAt: fetchedAt,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String productCode,
                Value<String?> productName = const Value.absent(),
                Value<String?> price = const Value.absent(),
                required int fetchedAt,
                required String source,
                Value<int> rowid = const Value.absent(),
              }) => QuoteCacheTableCompanion.insert(
                productCode: productCode,
                productName: productName,
                price: price,
                fetchedAt: fetchedAt,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuoteCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuoteCacheTableTable,
      QuoteCacheTableData,
      $$QuoteCacheTableTableFilterComposer,
      $$QuoteCacheTableTableOrderingComposer,
      $$QuoteCacheTableTableAnnotationComposer,
      $$QuoteCacheTableTableCreateCompanionBuilder,
      $$QuoteCacheTableTableUpdateCompanionBuilder,
      (
        QuoteCacheTableData,
        BaseReferences<
          _$AppDatabase,
          $QuoteCacheTableTable,
          QuoteCacheTableData
        >,
      ),
      QuoteCacheTableData,
      PrefetchHooks Function()
    >;
typedef $$ClassificationRuleTableTableCreateCompanionBuilder =
    ClassificationRuleTableCompanion Function({
      required String id,
      required String pattern,
      Value<String?> instrumentType,
      Value<String?> assetClass,
      required int priority,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$ClassificationRuleTableTableUpdateCompanionBuilder =
    ClassificationRuleTableCompanion Function({
      Value<String> id,
      Value<String> pattern,
      Value<String?> instrumentType,
      Value<String?> assetClass,
      Value<int> priority,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$ClassificationRuleTableTableFilterComposer
    extends Composer<_$AppDatabase, $ClassificationRuleTableTable> {
  $$ClassificationRuleTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instrumentType => $composableBuilder(
    column: $table.instrumentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClassificationRuleTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ClassificationRuleTableTable> {
  $$ClassificationRuleTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instrumentType => $composableBuilder(
    column: $table.instrumentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClassificationRuleTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClassificationRuleTableTable> {
  $$ClassificationRuleTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get instrumentType => $composableBuilder(
    column: $table.instrumentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ClassificationRuleTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClassificationRuleTableTable,
          ClassificationRuleTableData,
          $$ClassificationRuleTableTableFilterComposer,
          $$ClassificationRuleTableTableOrderingComposer,
          $$ClassificationRuleTableTableAnnotationComposer,
          $$ClassificationRuleTableTableCreateCompanionBuilder,
          $$ClassificationRuleTableTableUpdateCompanionBuilder,
          (
            ClassificationRuleTableData,
            BaseReferences<
              _$AppDatabase,
              $ClassificationRuleTableTable,
              ClassificationRuleTableData
            >,
          ),
          ClassificationRuleTableData,
          PrefetchHooks Function()
        > {
  $$ClassificationRuleTableTableTableManager(
    _$AppDatabase db,
    $ClassificationRuleTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClassificationRuleTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ClassificationRuleTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ClassificationRuleTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> pattern = const Value.absent(),
                Value<String?> instrumentType = const Value.absent(),
                Value<String?> assetClass = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClassificationRuleTableCompanion(
                id: id,
                pattern: pattern,
                instrumentType: instrumentType,
                assetClass: assetClass,
                priority: priority,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String pattern,
                Value<String?> instrumentType = const Value.absent(),
                Value<String?> assetClass = const Value.absent(),
                required int priority,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ClassificationRuleTableCompanion.insert(
                id: id,
                pattern: pattern,
                instrumentType: instrumentType,
                assetClass: assetClass,
                priority: priority,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClassificationRuleTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClassificationRuleTableTable,
      ClassificationRuleTableData,
      $$ClassificationRuleTableTableFilterComposer,
      $$ClassificationRuleTableTableOrderingComposer,
      $$ClassificationRuleTableTableAnnotationComposer,
      $$ClassificationRuleTableTableCreateCompanionBuilder,
      $$ClassificationRuleTableTableUpdateCompanionBuilder,
      (
        ClassificationRuleTableData,
        BaseReferences<
          _$AppDatabase,
          $ClassificationRuleTableTable,
          ClassificationRuleTableData
        >,
      ),
      ClassificationRuleTableData,
      PrefetchHooks Function()
    >;
typedef $$AppSettingTableTableCreateCompanionBuilder =
    AppSettingTableCompanion Function({
      required String key,
      required String value,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingTableTableUpdateCompanionBuilder =
    AppSettingTableCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingTableTable> {
  $$AppSettingTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingTableTable> {
  $$AppSettingTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingTableTable> {
  $$AppSettingTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingTableTable,
          AppSettingTableData,
          $$AppSettingTableTableFilterComposer,
          $$AppSettingTableTableOrderingComposer,
          $$AppSettingTableTableAnnotationComposer,
          $$AppSettingTableTableCreateCompanionBuilder,
          $$AppSettingTableTableUpdateCompanionBuilder,
          (
            AppSettingTableData,
            BaseReferences<
              _$AppDatabase,
              $AppSettingTableTable,
              AppSettingTableData
            >,
          ),
          AppSettingTableData,
          PrefetchHooks Function()
        > {
  $$AppSettingTableTableTableManager(
    _$AppDatabase db,
    $AppSettingTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingTableCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingTableCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingTableTable,
      AppSettingTableData,
      $$AppSettingTableTableFilterComposer,
      $$AppSettingTableTableOrderingComposer,
      $$AppSettingTableTableAnnotationComposer,
      $$AppSettingTableTableCreateCompanionBuilder,
      $$AppSettingTableTableUpdateCompanionBuilder,
      (
        AppSettingTableData,
        BaseReferences<
          _$AppDatabase,
          $AppSettingTableTable,
          AppSettingTableData
        >,
      ),
      AppSettingTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HoldingTableTableTableManager get holdingTable =>
      $$HoldingTableTableTableManager(_db, _db.holdingTable);
  $$SnapshotTableTableTableManager get snapshotTable =>
      $$SnapshotTableTableTableManager(_db, _db.snapshotTable);
  $$SnapshotHoldingTableTableTableManager get snapshotHoldingTable =>
      $$SnapshotHoldingTableTableTableManager(_db, _db.snapshotHoldingTable);
  $$ImportBatchTableTableTableManager get importBatchTable =>
      $$ImportBatchTableTableTableManager(_db, _db.importBatchTable);
  $$DraftHoldingTableTableTableManager get draftHoldingTable =>
      $$DraftHoldingTableTableTableManager(_db, _db.draftHoldingTable);
  $$DataIssueTableTableTableManager get dataIssueTable =>
      $$DataIssueTableTableTableManager(_db, _db.dataIssueTable);
  $$QuoteCacheTableTableTableManager get quoteCacheTable =>
      $$QuoteCacheTableTableTableManager(_db, _db.quoteCacheTable);
  $$ClassificationRuleTableTableTableManager get classificationRuleTable =>
      $$ClassificationRuleTableTableTableManager(
        _db,
        _db.classificationRuleTable,
      );
  $$AppSettingTableTableTableManager get appSettingTable =>
      $$AppSettingTableTableTableManager(_db, _db.appSettingTable);
}
