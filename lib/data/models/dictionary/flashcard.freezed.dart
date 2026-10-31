// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'flashcard.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Flashcard {

 int get id; String get note; String get createdAt; WordSummary get word;
/// Create a copy of Flashcard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlashcardCopyWith<Flashcard> get copyWith => _$FlashcardCopyWithImpl<Flashcard>(this as Flashcard, _$identity);

  /// Serializes this Flashcard to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Flashcard&&(identical(other.id, id) || other.id == id)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.word, word) || other.word == word));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,note,createdAt,word);

@override
String toString() {
  return 'Flashcard(id: $id, note: $note, createdAt: $createdAt, word: $word)';
}


}

/// @nodoc
abstract mixin class $FlashcardCopyWith<$Res>  {
  factory $FlashcardCopyWith(Flashcard value, $Res Function(Flashcard) _then) = _$FlashcardCopyWithImpl;
@useResult
$Res call({
 int id, String note, String createdAt, WordSummary word
});


$WordSummaryCopyWith<$Res> get word;

}
/// @nodoc
class _$FlashcardCopyWithImpl<$Res>
    implements $FlashcardCopyWith<$Res> {
  _$FlashcardCopyWithImpl(this._self, this._then);

  final Flashcard _self;
  final $Res Function(Flashcard) _then;

/// Create a copy of Flashcard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? note = null,Object? createdAt = null,Object? word = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,word: null == word ? _self.word : word // ignore: cast_nullable_to_non_nullable
as WordSummary,
  ));
}
/// Create a copy of Flashcard
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WordSummaryCopyWith<$Res> get word {
  
  return $WordSummaryCopyWith<$Res>(_self.word, (value) {
    return _then(_self.copyWith(word: value));
  });
}
}


/// Adds pattern-matching-related methods to [Flashcard].
extension FlashcardPatterns on Flashcard {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Flashcard value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Flashcard() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Flashcard value)  $default,){
final _that = this;
switch (_that) {
case _Flashcard():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Flashcard value)?  $default,){
final _that = this;
switch (_that) {
case _Flashcard() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String note,  String createdAt,  WordSummary word)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Flashcard() when $default != null:
return $default(_that.id,_that.note,_that.createdAt,_that.word);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String note,  String createdAt,  WordSummary word)  $default,) {final _that = this;
switch (_that) {
case _Flashcard():
return $default(_that.id,_that.note,_that.createdAt,_that.word);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String note,  String createdAt,  WordSummary word)?  $default,) {final _that = this;
switch (_that) {
case _Flashcard() when $default != null:
return $default(_that.id,_that.note,_that.createdAt,_that.word);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Flashcard implements Flashcard {
  const _Flashcard({required this.id, required this.note, required this.createdAt, required this.word});
  factory _Flashcard.fromJson(Map<String, dynamic> json) => _$FlashcardFromJson(json);

@override final  int id;
@override final  String note;
@override final  String createdAt;
@override final  WordSummary word;

/// Create a copy of Flashcard
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlashcardCopyWith<_Flashcard> get copyWith => __$FlashcardCopyWithImpl<_Flashcard>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlashcardToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Flashcard&&(identical(other.id, id) || other.id == id)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.word, word) || other.word == word));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,note,createdAt,word);

@override
String toString() {
  return 'Flashcard(id: $id, note: $note, createdAt: $createdAt, word: $word)';
}


}

/// @nodoc
abstract mixin class _$FlashcardCopyWith<$Res> implements $FlashcardCopyWith<$Res> {
  factory _$FlashcardCopyWith(_Flashcard value, $Res Function(_Flashcard) _then) = __$FlashcardCopyWithImpl;
@override @useResult
$Res call({
 int id, String note, String createdAt, WordSummary word
});


@override $WordSummaryCopyWith<$Res> get word;

}
/// @nodoc
class __$FlashcardCopyWithImpl<$Res>
    implements _$FlashcardCopyWith<$Res> {
  __$FlashcardCopyWithImpl(this._self, this._then);

  final _Flashcard _self;
  final $Res Function(_Flashcard) _then;

/// Create a copy of Flashcard
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? note = null,Object? createdAt = null,Object? word = null,}) {
  return _then(_Flashcard(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,word: null == word ? _self.word : word // ignore: cast_nullable_to_non_nullable
as WordSummary,
  ));
}

/// Create a copy of Flashcard
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WordSummaryCopyWith<$Res> get word {
  
  return $WordSummaryCopyWith<$Res>(_self.word, (value) {
    return _then(_self.copyWith(word: value));
  });
}
}


/// @nodoc
mixin _$GetFlashcardsResponse {

 List<Flashcard> get data; int get page; int get pageCounts; int get total;
/// Create a copy of GetFlashcardsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GetFlashcardsResponseCopyWith<GetFlashcardsResponse> get copyWith => _$GetFlashcardsResponseCopyWithImpl<GetFlashcardsResponse>(this as GetFlashcardsResponse, _$identity);

  /// Serializes this GetFlashcardsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GetFlashcardsResponse&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageCounts, pageCounts) || other.pageCounts == pageCounts)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),page,pageCounts,total);

@override
String toString() {
  return 'GetFlashcardsResponse(data: $data, page: $page, pageCounts: $pageCounts, total: $total)';
}


}

/// @nodoc
abstract mixin class $GetFlashcardsResponseCopyWith<$Res>  {
  factory $GetFlashcardsResponseCopyWith(GetFlashcardsResponse value, $Res Function(GetFlashcardsResponse) _then) = _$GetFlashcardsResponseCopyWithImpl;
@useResult
$Res call({
 List<Flashcard> data, int page, int pageCounts, int total
});




}
/// @nodoc
class _$GetFlashcardsResponseCopyWithImpl<$Res>
    implements $GetFlashcardsResponseCopyWith<$Res> {
  _$GetFlashcardsResponseCopyWithImpl(this._self, this._then);

  final GetFlashcardsResponse _self;
  final $Res Function(GetFlashcardsResponse) _then;

/// Create a copy of GetFlashcardsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? page = null,Object? pageCounts = null,Object? total = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<Flashcard>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageCounts: null == pageCounts ? _self.pageCounts : pageCounts // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GetFlashcardsResponse].
extension GetFlashcardsResponsePatterns on GetFlashcardsResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GetFlashcardsResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GetFlashcardsResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GetFlashcardsResponse value)  $default,){
final _that = this;
switch (_that) {
case _GetFlashcardsResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GetFlashcardsResponse value)?  $default,){
final _that = this;
switch (_that) {
case _GetFlashcardsResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Flashcard> data,  int page,  int pageCounts,  int total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GetFlashcardsResponse() when $default != null:
return $default(_that.data,_that.page,_that.pageCounts,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Flashcard> data,  int page,  int pageCounts,  int total)  $default,) {final _that = this;
switch (_that) {
case _GetFlashcardsResponse():
return $default(_that.data,_that.page,_that.pageCounts,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Flashcard> data,  int page,  int pageCounts,  int total)?  $default,) {final _that = this;
switch (_that) {
case _GetFlashcardsResponse() when $default != null:
return $default(_that.data,_that.page,_that.pageCounts,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GetFlashcardsResponse implements GetFlashcardsResponse {
  const _GetFlashcardsResponse({final  List<Flashcard> data = const [], required this.page, required this.pageCounts, required this.total}): _data = data;
  factory _GetFlashcardsResponse.fromJson(Map<String, dynamic> json) => _$GetFlashcardsResponseFromJson(json);

 final  List<Flashcard> _data;
@override@JsonKey() List<Flashcard> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  int page;
@override final  int pageCounts;
@override final  int total;

/// Create a copy of GetFlashcardsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GetFlashcardsResponseCopyWith<_GetFlashcardsResponse> get copyWith => __$GetFlashcardsResponseCopyWithImpl<_GetFlashcardsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GetFlashcardsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GetFlashcardsResponse&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageCounts, pageCounts) || other.pageCounts == pageCounts)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),page,pageCounts,total);

@override
String toString() {
  return 'GetFlashcardsResponse(data: $data, page: $page, pageCounts: $pageCounts, total: $total)';
}


}

/// @nodoc
abstract mixin class _$GetFlashcardsResponseCopyWith<$Res> implements $GetFlashcardsResponseCopyWith<$Res> {
  factory _$GetFlashcardsResponseCopyWith(_GetFlashcardsResponse value, $Res Function(_GetFlashcardsResponse) _then) = __$GetFlashcardsResponseCopyWithImpl;
@override @useResult
$Res call({
 List<Flashcard> data, int page, int pageCounts, int total
});




}
/// @nodoc
class __$GetFlashcardsResponseCopyWithImpl<$Res>
    implements _$GetFlashcardsResponseCopyWith<$Res> {
  __$GetFlashcardsResponseCopyWithImpl(this._self, this._then);

  final _GetFlashcardsResponse _self;
  final $Res Function(_GetFlashcardsResponse) _then;

/// Create a copy of GetFlashcardsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? page = null,Object? pageCounts = null,Object? total = null,}) {
  return _then(_GetFlashcardsResponse(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<Flashcard>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageCounts: null == pageCounts ? _self.pageCounts : pageCounts // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
