// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dictionary_topic.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DictionaryTopic {

 int get id; String get name; String get category; String? get description; String? get icon; String? get level;
/// Create a copy of DictionaryTopic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DictionaryTopicCopyWith<DictionaryTopic> get copyWith => _$DictionaryTopicCopyWithImpl<DictionaryTopic>(this as DictionaryTopic, _$identity);

  /// Serializes this DictionaryTopic to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DictionaryTopic&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.description, description) || other.description == description)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.level, level) || other.level == level));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,category,description,icon,level);

@override
String toString() {
  return 'DictionaryTopic(id: $id, name: $name, category: $category, description: $description, icon: $icon, level: $level)';
}


}

/// @nodoc
abstract mixin class $DictionaryTopicCopyWith<$Res>  {
  factory $DictionaryTopicCopyWith(DictionaryTopic value, $Res Function(DictionaryTopic) _then) = _$DictionaryTopicCopyWithImpl;
@useResult
$Res call({
 int id, String name, String category, String? description, String? icon, String? level
});




}
/// @nodoc
class _$DictionaryTopicCopyWithImpl<$Res>
    implements $DictionaryTopicCopyWith<$Res> {
  _$DictionaryTopicCopyWithImpl(this._self, this._then);

  final DictionaryTopic _self;
  final $Res Function(DictionaryTopic) _then;

/// Create a copy of DictionaryTopic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? category = null,Object? description = freezed,Object? icon = freezed,Object? level = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,level: freezed == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DictionaryTopic].
extension DictionaryTopicPatterns on DictionaryTopic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DictionaryTopic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DictionaryTopic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DictionaryTopic value)  $default,){
final _that = this;
switch (_that) {
case _DictionaryTopic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DictionaryTopic value)?  $default,){
final _that = this;
switch (_that) {
case _DictionaryTopic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String category,  String? description,  String? icon,  String? level)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DictionaryTopic() when $default != null:
return $default(_that.id,_that.name,_that.category,_that.description,_that.icon,_that.level);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String category,  String? description,  String? icon,  String? level)  $default,) {final _that = this;
switch (_that) {
case _DictionaryTopic():
return $default(_that.id,_that.name,_that.category,_that.description,_that.icon,_that.level);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String category,  String? description,  String? icon,  String? level)?  $default,) {final _that = this;
switch (_that) {
case _DictionaryTopic() when $default != null:
return $default(_that.id,_that.name,_that.category,_that.description,_that.icon,_that.level);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DictionaryTopic implements DictionaryTopic {
  const _DictionaryTopic({required this.id, required this.name, required this.category, this.description, this.icon, this.level});
  factory _DictionaryTopic.fromJson(Map<String, dynamic> json) => _$DictionaryTopicFromJson(json);

@override final  int id;
@override final  String name;
@override final  String category;
@override final  String? description;
@override final  String? icon;
@override final  String? level;

/// Create a copy of DictionaryTopic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DictionaryTopicCopyWith<_DictionaryTopic> get copyWith => __$DictionaryTopicCopyWithImpl<_DictionaryTopic>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DictionaryTopicToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DictionaryTopic&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.description, description) || other.description == description)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.level, level) || other.level == level));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,category,description,icon,level);

@override
String toString() {
  return 'DictionaryTopic(id: $id, name: $name, category: $category, description: $description, icon: $icon, level: $level)';
}


}

/// @nodoc
abstract mixin class _$DictionaryTopicCopyWith<$Res> implements $DictionaryTopicCopyWith<$Res> {
  factory _$DictionaryTopicCopyWith(_DictionaryTopic value, $Res Function(_DictionaryTopic) _then) = __$DictionaryTopicCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String category, String? description, String? icon, String? level
});




}
/// @nodoc
class __$DictionaryTopicCopyWithImpl<$Res>
    implements _$DictionaryTopicCopyWith<$Res> {
  __$DictionaryTopicCopyWithImpl(this._self, this._then);

  final _DictionaryTopic _self;
  final $Res Function(_DictionaryTopic) _then;

/// Create a copy of DictionaryTopic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? category = null,Object? description = freezed,Object? icon = freezed,Object? level = freezed,}) {
  return _then(_DictionaryTopic(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,level: freezed == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$TopicWordsResponse {

 List<WordSummary> get data; int get page; int get pageCounts; int get total;
/// Create a copy of TopicWordsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopicWordsResponseCopyWith<TopicWordsResponse> get copyWith => _$TopicWordsResponseCopyWithImpl<TopicWordsResponse>(this as TopicWordsResponse, _$identity);

  /// Serializes this TopicWordsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TopicWordsResponse&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageCounts, pageCounts) || other.pageCounts == pageCounts)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),page,pageCounts,total);

@override
String toString() {
  return 'TopicWordsResponse(data: $data, page: $page, pageCounts: $pageCounts, total: $total)';
}


}

/// @nodoc
abstract mixin class $TopicWordsResponseCopyWith<$Res>  {
  factory $TopicWordsResponseCopyWith(TopicWordsResponse value, $Res Function(TopicWordsResponse) _then) = _$TopicWordsResponseCopyWithImpl;
@useResult
$Res call({
 List<WordSummary> data, int page, int pageCounts, int total
});




}
/// @nodoc
class _$TopicWordsResponseCopyWithImpl<$Res>
    implements $TopicWordsResponseCopyWith<$Res> {
  _$TopicWordsResponseCopyWithImpl(this._self, this._then);

  final TopicWordsResponse _self;
  final $Res Function(TopicWordsResponse) _then;

/// Create a copy of TopicWordsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? page = null,Object? pageCounts = null,Object? total = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<WordSummary>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageCounts: null == pageCounts ? _self.pageCounts : pageCounts // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TopicWordsResponse].
extension TopicWordsResponsePatterns on TopicWordsResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TopicWordsResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TopicWordsResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TopicWordsResponse value)  $default,){
final _that = this;
switch (_that) {
case _TopicWordsResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TopicWordsResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TopicWordsResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<WordSummary> data,  int page,  int pageCounts,  int total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TopicWordsResponse() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<WordSummary> data,  int page,  int pageCounts,  int total)  $default,) {final _that = this;
switch (_that) {
case _TopicWordsResponse():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<WordSummary> data,  int page,  int pageCounts,  int total)?  $default,) {final _that = this;
switch (_that) {
case _TopicWordsResponse() when $default != null:
return $default(_that.data,_that.page,_that.pageCounts,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TopicWordsResponse implements TopicWordsResponse {
  const _TopicWordsResponse({final  List<WordSummary> data = const [], required this.page, required this.pageCounts, this.total = 0}): _data = data;
  factory _TopicWordsResponse.fromJson(Map<String, dynamic> json) => _$TopicWordsResponseFromJson(json);

 final  List<WordSummary> _data;
@override@JsonKey() List<WordSummary> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  int page;
@override final  int pageCounts;
@override@JsonKey() final  int total;

/// Create a copy of TopicWordsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopicWordsResponseCopyWith<_TopicWordsResponse> get copyWith => __$TopicWordsResponseCopyWithImpl<_TopicWordsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TopicWordsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TopicWordsResponse&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageCounts, pageCounts) || other.pageCounts == pageCounts)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),page,pageCounts,total);

@override
String toString() {
  return 'TopicWordsResponse(data: $data, page: $page, pageCounts: $pageCounts, total: $total)';
}


}

/// @nodoc
abstract mixin class _$TopicWordsResponseCopyWith<$Res> implements $TopicWordsResponseCopyWith<$Res> {
  factory _$TopicWordsResponseCopyWith(_TopicWordsResponse value, $Res Function(_TopicWordsResponse) _then) = __$TopicWordsResponseCopyWithImpl;
@override @useResult
$Res call({
 List<WordSummary> data, int page, int pageCounts, int total
});




}
/// @nodoc
class __$TopicWordsResponseCopyWithImpl<$Res>
    implements _$TopicWordsResponseCopyWith<$Res> {
  __$TopicWordsResponseCopyWithImpl(this._self, this._then);

  final _TopicWordsResponse _self;
  final $Res Function(_TopicWordsResponse) _then;

/// Create a copy of TopicWordsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? page = null,Object? pageCounts = null,Object? total = null,}) {
  return _then(_TopicWordsResponse(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<WordSummary>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageCounts: null == pageCounts ? _self.pageCounts : pageCounts // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
