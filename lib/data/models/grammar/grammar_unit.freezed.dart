// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'grammar_unit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UnitSummary {

 int get id; int get unit; String get title; bool get completed; int get total;
/// Create a copy of UnitSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnitSummaryCopyWith<UnitSummary> get copyWith => _$UnitSummaryCopyWithImpl<UnitSummary>(this as UnitSummary, _$identity);

  /// Serializes this UnitSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnitSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.title, title) || other.title == title)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,unit,title,completed,total);

@override
String toString() {
  return 'UnitSummary(id: $id, unit: $unit, title: $title, completed: $completed, total: $total)';
}


}

/// @nodoc
abstract mixin class $UnitSummaryCopyWith<$Res>  {
  factory $UnitSummaryCopyWith(UnitSummary value, $Res Function(UnitSummary) _then) = _$UnitSummaryCopyWithImpl;
@useResult
$Res call({
 int id, int unit, String title, bool completed, int total
});




}
/// @nodoc
class _$UnitSummaryCopyWithImpl<$Res>
    implements $UnitSummaryCopyWith<$Res> {
  _$UnitSummaryCopyWithImpl(this._self, this._then);

  final UnitSummary _self;
  final $Res Function(UnitSummary) _then;

/// Create a copy of UnitSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? unit = null,Object? title = null,Object? completed = null,Object? total = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UnitSummary].
extension UnitSummaryPatterns on UnitSummary {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UnitSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UnitSummary() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UnitSummary value)  $default,){
final _that = this;
switch (_that) {
case _UnitSummary():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UnitSummary value)?  $default,){
final _that = this;
switch (_that) {
case _UnitSummary() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int unit,  String title,  bool completed,  int total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UnitSummary() when $default != null:
return $default(_that.id,_that.unit,_that.title,_that.completed,_that.total);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int unit,  String title,  bool completed,  int total)  $default,) {final _that = this;
switch (_that) {
case _UnitSummary():
return $default(_that.id,_that.unit,_that.title,_that.completed,_that.total);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int unit,  String title,  bool completed,  int total)?  $default,) {final _that = this;
switch (_that) {
case _UnitSummary() when $default != null:
return $default(_that.id,_that.unit,_that.title,_that.completed,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UnitSummary extends UnitSummary {
  const _UnitSummary({required this.id, this.unit = 1, required this.title, this.completed = false, this.total = 0}): super._();
  factory _UnitSummary.fromJson(Map<String, dynamic> json) => _$UnitSummaryFromJson(json);

@override final  int id;
@override@JsonKey() final  int unit;
@override final  String title;
@override@JsonKey() final  bool completed;
@override@JsonKey() final  int total;

/// Create a copy of UnitSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnitSummaryCopyWith<_UnitSummary> get copyWith => __$UnitSummaryCopyWithImpl<_UnitSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UnitSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UnitSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.title, title) || other.title == title)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,unit,title,completed,total);

@override
String toString() {
  return 'UnitSummary(id: $id, unit: $unit, title: $title, completed: $completed, total: $total)';
}


}

/// @nodoc
abstract mixin class _$UnitSummaryCopyWith<$Res> implements $UnitSummaryCopyWith<$Res> {
  factory _$UnitSummaryCopyWith(_UnitSummary value, $Res Function(_UnitSummary) _then) = __$UnitSummaryCopyWithImpl;
@override @useResult
$Res call({
 int id, int unit, String title, bool completed, int total
});




}
/// @nodoc
class __$UnitSummaryCopyWithImpl<$Res>
    implements _$UnitSummaryCopyWith<$Res> {
  __$UnitSummaryCopyWithImpl(this._self, this._then);

  final _UnitSummary _self;
  final $Res Function(_UnitSummary) _then;

/// Create a copy of UnitSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? unit = null,Object? title = null,Object? completed = null,Object? total = null,}) {
  return _then(_UnitSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CurriculumResponse {

 List<UnitSummary> get data; int get total;
/// Create a copy of CurriculumResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CurriculumResponseCopyWith<CurriculumResponse> get copyWith => _$CurriculumResponseCopyWithImpl<CurriculumResponse>(this as CurriculumResponse, _$identity);

  /// Serializes this CurriculumResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CurriculumResponse&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),total);

@override
String toString() {
  return 'CurriculumResponse(data: $data, total: $total)';
}


}

/// @nodoc
abstract mixin class $CurriculumResponseCopyWith<$Res>  {
  factory $CurriculumResponseCopyWith(CurriculumResponse value, $Res Function(CurriculumResponse) _then) = _$CurriculumResponseCopyWithImpl;
@useResult
$Res call({
 List<UnitSummary> data, int total
});




}
/// @nodoc
class _$CurriculumResponseCopyWithImpl<$Res>
    implements $CurriculumResponseCopyWith<$Res> {
  _$CurriculumResponseCopyWithImpl(this._self, this._then);

  final CurriculumResponse _self;
  final $Res Function(CurriculumResponse) _then;

/// Create a copy of CurriculumResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? total = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<UnitSummary>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CurriculumResponse].
extension CurriculumResponsePatterns on CurriculumResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CurriculumResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CurriculumResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CurriculumResponse value)  $default,){
final _that = this;
switch (_that) {
case _CurriculumResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CurriculumResponse value)?  $default,){
final _that = this;
switch (_that) {
case _CurriculumResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<UnitSummary> data,  int total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CurriculumResponse() when $default != null:
return $default(_that.data,_that.total);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<UnitSummary> data,  int total)  $default,) {final _that = this;
switch (_that) {
case _CurriculumResponse():
return $default(_that.data,_that.total);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<UnitSummary> data,  int total)?  $default,) {final _that = this;
switch (_that) {
case _CurriculumResponse() when $default != null:
return $default(_that.data,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CurriculumResponse extends CurriculumResponse {
  const _CurriculumResponse({final  List<UnitSummary> data = const [], this.total = 0}): _data = data,super._();
  factory _CurriculumResponse.fromJson(Map<String, dynamic> json) => _$CurriculumResponseFromJson(json);

 final  List<UnitSummary> _data;
@override@JsonKey() List<UnitSummary> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override@JsonKey() final  int total;

/// Create a copy of CurriculumResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CurriculumResponseCopyWith<_CurriculumResponse> get copyWith => __$CurriculumResponseCopyWithImpl<_CurriculumResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CurriculumResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CurriculumResponse&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),total);

@override
String toString() {
  return 'CurriculumResponse(data: $data, total: $total)';
}


}

/// @nodoc
abstract mixin class _$CurriculumResponseCopyWith<$Res> implements $CurriculumResponseCopyWith<$Res> {
  factory _$CurriculumResponseCopyWith(_CurriculumResponse value, $Res Function(_CurriculumResponse) _then) = __$CurriculumResponseCopyWithImpl;
@override @useResult
$Res call({
 List<UnitSummary> data, int total
});




}
/// @nodoc
class __$CurriculumResponseCopyWithImpl<$Res>
    implements _$CurriculumResponseCopyWith<$Res> {
  __$CurriculumResponseCopyWithImpl(this._self, this._then);

  final _CurriculumResponse _self;
  final $Res Function(_CurriculumResponse) _then;

/// Create a copy of CurriculumResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? total = null,}) {
  return _then(_CurriculumResponse(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<UnitSummary>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$PracticeQuestion {

 int get id; String get question; List<String> get options; String get correct; String get explanation; int? get sortOrder;
/// Create a copy of PracticeQuestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PracticeQuestionCopyWith<PracticeQuestion> get copyWith => _$PracticeQuestionCopyWithImpl<PracticeQuestion>(this as PracticeQuestion, _$identity);

  /// Serializes this PracticeQuestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PracticeQuestion&&(identical(other.id, id) || other.id == id)&&(identical(other.question, question) || other.question == question)&&const DeepCollectionEquality().equals(other.options, options)&&(identical(other.correct, correct) || other.correct == correct)&&(identical(other.explanation, explanation) || other.explanation == explanation)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,question,const DeepCollectionEquality().hash(options),correct,explanation,sortOrder);

@override
String toString() {
  return 'PracticeQuestion(id: $id, question: $question, options: $options, correct: $correct, explanation: $explanation, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class $PracticeQuestionCopyWith<$Res>  {
  factory $PracticeQuestionCopyWith(PracticeQuestion value, $Res Function(PracticeQuestion) _then) = _$PracticeQuestionCopyWithImpl;
@useResult
$Res call({
 int id, String question, List<String> options, String correct, String explanation, int? sortOrder
});




}
/// @nodoc
class _$PracticeQuestionCopyWithImpl<$Res>
    implements $PracticeQuestionCopyWith<$Res> {
  _$PracticeQuestionCopyWithImpl(this._self, this._then);

  final PracticeQuestion _self;
  final $Res Function(PracticeQuestion) _then;

/// Create a copy of PracticeQuestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? question = null,Object? options = null,Object? correct = null,Object? explanation = null,Object? sortOrder = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<String>,correct: null == correct ? _self.correct : correct // ignore: cast_nullable_to_non_nullable
as String,explanation: null == explanation ? _self.explanation : explanation // ignore: cast_nullable_to_non_nullable
as String,sortOrder: freezed == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PracticeQuestion].
extension PracticeQuestionPatterns on PracticeQuestion {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PracticeQuestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PracticeQuestion() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PracticeQuestion value)  $default,){
final _that = this;
switch (_that) {
case _PracticeQuestion():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PracticeQuestion value)?  $default,){
final _that = this;
switch (_that) {
case _PracticeQuestion() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String question,  List<String> options,  String correct,  String explanation,  int? sortOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PracticeQuestion() when $default != null:
return $default(_that.id,_that.question,_that.options,_that.correct,_that.explanation,_that.sortOrder);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String question,  List<String> options,  String correct,  String explanation,  int? sortOrder)  $default,) {final _that = this;
switch (_that) {
case _PracticeQuestion():
return $default(_that.id,_that.question,_that.options,_that.correct,_that.explanation,_that.sortOrder);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String question,  List<String> options,  String correct,  String explanation,  int? sortOrder)?  $default,) {final _that = this;
switch (_that) {
case _PracticeQuestion() when $default != null:
return $default(_that.id,_that.question,_that.options,_that.correct,_that.explanation,_that.sortOrder);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PracticeQuestion extends PracticeQuestion {
  const _PracticeQuestion({required this.id, required this.question, final  List<String> options = const [], required this.correct, required this.explanation, this.sortOrder}): _options = options,super._();
  factory _PracticeQuestion.fromJson(Map<String, dynamic> json) => _$PracticeQuestionFromJson(json);

@override final  int id;
@override final  String question;
 final  List<String> _options;
@override@JsonKey() List<String> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override final  String correct;
@override final  String explanation;
@override final  int? sortOrder;

/// Create a copy of PracticeQuestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PracticeQuestionCopyWith<_PracticeQuestion> get copyWith => __$PracticeQuestionCopyWithImpl<_PracticeQuestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PracticeQuestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PracticeQuestion&&(identical(other.id, id) || other.id == id)&&(identical(other.question, question) || other.question == question)&&const DeepCollectionEquality().equals(other._options, _options)&&(identical(other.correct, correct) || other.correct == correct)&&(identical(other.explanation, explanation) || other.explanation == explanation)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,question,const DeepCollectionEquality().hash(_options),correct,explanation,sortOrder);

@override
String toString() {
  return 'PracticeQuestion(id: $id, question: $question, options: $options, correct: $correct, explanation: $explanation, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class _$PracticeQuestionCopyWith<$Res> implements $PracticeQuestionCopyWith<$Res> {
  factory _$PracticeQuestionCopyWith(_PracticeQuestion value, $Res Function(_PracticeQuestion) _then) = __$PracticeQuestionCopyWithImpl;
@override @useResult
$Res call({
 int id, String question, List<String> options, String correct, String explanation, int? sortOrder
});




}
/// @nodoc
class __$PracticeQuestionCopyWithImpl<$Res>
    implements _$PracticeQuestionCopyWith<$Res> {
  __$PracticeQuestionCopyWithImpl(this._self, this._then);

  final _PracticeQuestion _self;
  final $Res Function(_PracticeQuestion) _then;

/// Create a copy of PracticeQuestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? question = null,Object? options = null,Object? correct = null,Object? explanation = null,Object? sortOrder = freezed,}) {
  return _then(_PracticeQuestion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<String>,correct: null == correct ? _self.correct : correct // ignore: cast_nullable_to_non_nullable
as String,explanation: null == explanation ? _self.explanation : explanation // ignore: cast_nullable_to_non_nullable
as String,sortOrder: freezed == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$UnitDetail {

 int get id; int get unit; String get title; String get theory; List<String> get examples; List<PracticeQuestion> get practices; bool get completed;
/// Create a copy of UnitDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnitDetailCopyWith<UnitDetail> get copyWith => _$UnitDetailCopyWithImpl<UnitDetail>(this as UnitDetail, _$identity);

  /// Serializes this UnitDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnitDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.title, title) || other.title == title)&&(identical(other.theory, theory) || other.theory == theory)&&const DeepCollectionEquality().equals(other.examples, examples)&&const DeepCollectionEquality().equals(other.practices, practices)&&(identical(other.completed, completed) || other.completed == completed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,unit,title,theory,const DeepCollectionEquality().hash(examples),const DeepCollectionEquality().hash(practices),completed);

@override
String toString() {
  return 'UnitDetail(id: $id, unit: $unit, title: $title, theory: $theory, examples: $examples, practices: $practices, completed: $completed)';
}


}

/// @nodoc
abstract mixin class $UnitDetailCopyWith<$Res>  {
  factory $UnitDetailCopyWith(UnitDetail value, $Res Function(UnitDetail) _then) = _$UnitDetailCopyWithImpl;
@useResult
$Res call({
 int id, int unit, String title, String theory, List<String> examples, List<PracticeQuestion> practices, bool completed
});




}
/// @nodoc
class _$UnitDetailCopyWithImpl<$Res>
    implements $UnitDetailCopyWith<$Res> {
  _$UnitDetailCopyWithImpl(this._self, this._then);

  final UnitDetail _self;
  final $Res Function(UnitDetail) _then;

/// Create a copy of UnitDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? unit = null,Object? title = null,Object? theory = null,Object? examples = null,Object? practices = null,Object? completed = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,theory: null == theory ? _self.theory : theory // ignore: cast_nullable_to_non_nullable
as String,examples: null == examples ? _self.examples : examples // ignore: cast_nullable_to_non_nullable
as List<String>,practices: null == practices ? _self.practices : practices // ignore: cast_nullable_to_non_nullable
as List<PracticeQuestion>,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UnitDetail].
extension UnitDetailPatterns on UnitDetail {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UnitDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UnitDetail() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UnitDetail value)  $default,){
final _that = this;
switch (_that) {
case _UnitDetail():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UnitDetail value)?  $default,){
final _that = this;
switch (_that) {
case _UnitDetail() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int unit,  String title,  String theory,  List<String> examples,  List<PracticeQuestion> practices,  bool completed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UnitDetail() when $default != null:
return $default(_that.id,_that.unit,_that.title,_that.theory,_that.examples,_that.practices,_that.completed);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int unit,  String title,  String theory,  List<String> examples,  List<PracticeQuestion> practices,  bool completed)  $default,) {final _that = this;
switch (_that) {
case _UnitDetail():
return $default(_that.id,_that.unit,_that.title,_that.theory,_that.examples,_that.practices,_that.completed);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int unit,  String title,  String theory,  List<String> examples,  List<PracticeQuestion> practices,  bool completed)?  $default,) {final _that = this;
switch (_that) {
case _UnitDetail() when $default != null:
return $default(_that.id,_that.unit,_that.title,_that.theory,_that.examples,_that.practices,_that.completed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UnitDetail extends UnitDetail {
  const _UnitDetail({required this.id, this.unit = 1, required this.title, required this.theory, final  List<String> examples = const [], final  List<PracticeQuestion> practices = const [], this.completed = false}): _examples = examples,_practices = practices,super._();
  factory _UnitDetail.fromJson(Map<String, dynamic> json) => _$UnitDetailFromJson(json);

@override final  int id;
@override@JsonKey() final  int unit;
@override final  String title;
@override final  String theory;
 final  List<String> _examples;
@override@JsonKey() List<String> get examples {
  if (_examples is EqualUnmodifiableListView) return _examples;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_examples);
}

 final  List<PracticeQuestion> _practices;
@override@JsonKey() List<PracticeQuestion> get practices {
  if (_practices is EqualUnmodifiableListView) return _practices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_practices);
}

@override@JsonKey() final  bool completed;

/// Create a copy of UnitDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnitDetailCopyWith<_UnitDetail> get copyWith => __$UnitDetailCopyWithImpl<_UnitDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UnitDetailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UnitDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.title, title) || other.title == title)&&(identical(other.theory, theory) || other.theory == theory)&&const DeepCollectionEquality().equals(other._examples, _examples)&&const DeepCollectionEquality().equals(other._practices, _practices)&&(identical(other.completed, completed) || other.completed == completed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,unit,title,theory,const DeepCollectionEquality().hash(_examples),const DeepCollectionEquality().hash(_practices),completed);

@override
String toString() {
  return 'UnitDetail(id: $id, unit: $unit, title: $title, theory: $theory, examples: $examples, practices: $practices, completed: $completed)';
}


}

/// @nodoc
abstract mixin class _$UnitDetailCopyWith<$Res> implements $UnitDetailCopyWith<$Res> {
  factory _$UnitDetailCopyWith(_UnitDetail value, $Res Function(_UnitDetail) _then) = __$UnitDetailCopyWithImpl;
@override @useResult
$Res call({
 int id, int unit, String title, String theory, List<String> examples, List<PracticeQuestion> practices, bool completed
});




}
/// @nodoc
class __$UnitDetailCopyWithImpl<$Res>
    implements _$UnitDetailCopyWith<$Res> {
  __$UnitDetailCopyWithImpl(this._self, this._then);

  final _UnitDetail _self;
  final $Res Function(_UnitDetail) _then;

/// Create a copy of UnitDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? unit = null,Object? title = null,Object? theory = null,Object? examples = null,Object? practices = null,Object? completed = null,}) {
  return _then(_UnitDetail(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,theory: null == theory ? _self.theory : theory // ignore: cast_nullable_to_non_nullable
as String,examples: null == examples ? _self._examples : examples // ignore: cast_nullable_to_non_nullable
as List<String>,practices: null == practices ? _self._practices : practices // ignore: cast_nullable_to_non_nullable
as List<PracticeQuestion>,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
