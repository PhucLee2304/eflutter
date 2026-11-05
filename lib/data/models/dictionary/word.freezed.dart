// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'word.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Phonetic {

 String? get text; String? get audioUrl; String? get sourceUrl;
/// Create a copy of Phonetic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhoneticCopyWith<Phonetic> get copyWith => _$PhoneticCopyWithImpl<Phonetic>(this as Phonetic, _$identity);

  /// Serializes this Phonetic to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Phonetic&&(identical(other.text, text) || other.text == text)&&(identical(other.audioUrl, audioUrl) || other.audioUrl == audioUrl)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,audioUrl,sourceUrl);

@override
String toString() {
  return 'Phonetic(text: $text, audioUrl: $audioUrl, sourceUrl: $sourceUrl)';
}


}

/// @nodoc
abstract mixin class $PhoneticCopyWith<$Res>  {
  factory $PhoneticCopyWith(Phonetic value, $Res Function(Phonetic) _then) = _$PhoneticCopyWithImpl;
@useResult
$Res call({
 String? text, String? audioUrl, String? sourceUrl
});




}
/// @nodoc
class _$PhoneticCopyWithImpl<$Res>
    implements $PhoneticCopyWith<$Res> {
  _$PhoneticCopyWithImpl(this._self, this._then);

  final Phonetic _self;
  final $Res Function(Phonetic) _then;

/// Create a copy of Phonetic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = freezed,Object? audioUrl = freezed,Object? sourceUrl = freezed,}) {
  return _then(_self.copyWith(
text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,audioUrl: freezed == audioUrl ? _self.audioUrl : audioUrl // ignore: cast_nullable_to_non_nullable
as String?,sourceUrl: freezed == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Phonetic].
extension PhoneticPatterns on Phonetic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Phonetic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Phonetic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Phonetic value)  $default,){
final _that = this;
switch (_that) {
case _Phonetic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Phonetic value)?  $default,){
final _that = this;
switch (_that) {
case _Phonetic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? text,  String? audioUrl,  String? sourceUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Phonetic() when $default != null:
return $default(_that.text,_that.audioUrl,_that.sourceUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? text,  String? audioUrl,  String? sourceUrl)  $default,) {final _that = this;
switch (_that) {
case _Phonetic():
return $default(_that.text,_that.audioUrl,_that.sourceUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? text,  String? audioUrl,  String? sourceUrl)?  $default,) {final _that = this;
switch (_that) {
case _Phonetic() when $default != null:
return $default(_that.text,_that.audioUrl,_that.sourceUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Phonetic implements Phonetic {
  const _Phonetic({this.text, this.audioUrl, this.sourceUrl});
  factory _Phonetic.fromJson(Map<String, dynamic> json) => _$PhoneticFromJson(json);

@override final  String? text;
@override final  String? audioUrl;
@override final  String? sourceUrl;

/// Create a copy of Phonetic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhoneticCopyWith<_Phonetic> get copyWith => __$PhoneticCopyWithImpl<_Phonetic>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PhoneticToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Phonetic&&(identical(other.text, text) || other.text == text)&&(identical(other.audioUrl, audioUrl) || other.audioUrl == audioUrl)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,audioUrl,sourceUrl);

@override
String toString() {
  return 'Phonetic(text: $text, audioUrl: $audioUrl, sourceUrl: $sourceUrl)';
}


}

/// @nodoc
abstract mixin class _$PhoneticCopyWith<$Res> implements $PhoneticCopyWith<$Res> {
  factory _$PhoneticCopyWith(_Phonetic value, $Res Function(_Phonetic) _then) = __$PhoneticCopyWithImpl;
@override @useResult
$Res call({
 String? text, String? audioUrl, String? sourceUrl
});




}
/// @nodoc
class __$PhoneticCopyWithImpl<$Res>
    implements _$PhoneticCopyWith<$Res> {
  __$PhoneticCopyWithImpl(this._self, this._then);

  final _Phonetic _self;
  final $Res Function(_Phonetic) _then;

/// Create a copy of Phonetic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = freezed,Object? audioUrl = freezed,Object? sourceUrl = freezed,}) {
  return _then(_Phonetic(
text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,audioUrl: freezed == audioUrl ? _self.audioUrl : audioUrl // ignore: cast_nullable_to_non_nullable
as String?,sourceUrl: freezed == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Definition {

 String get definition; String? get example; List<String> get synonyms; List<String> get antonyms;
/// Create a copy of Definition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DefinitionCopyWith<Definition> get copyWith => _$DefinitionCopyWithImpl<Definition>(this as Definition, _$identity);

  /// Serializes this Definition to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Definition&&(identical(other.definition, definition) || other.definition == definition)&&(identical(other.example, example) || other.example == example)&&const DeepCollectionEquality().equals(other.synonyms, synonyms)&&const DeepCollectionEquality().equals(other.antonyms, antonyms));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,definition,example,const DeepCollectionEquality().hash(synonyms),const DeepCollectionEquality().hash(antonyms));

@override
String toString() {
  return 'Definition(definition: $definition, example: $example, synonyms: $synonyms, antonyms: $antonyms)';
}


}

/// @nodoc
abstract mixin class $DefinitionCopyWith<$Res>  {
  factory $DefinitionCopyWith(Definition value, $Res Function(Definition) _then) = _$DefinitionCopyWithImpl;
@useResult
$Res call({
 String definition, String? example, List<String> synonyms, List<String> antonyms
});




}
/// @nodoc
class _$DefinitionCopyWithImpl<$Res>
    implements $DefinitionCopyWith<$Res> {
  _$DefinitionCopyWithImpl(this._self, this._then);

  final Definition _self;
  final $Res Function(Definition) _then;

/// Create a copy of Definition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? definition = null,Object? example = freezed,Object? synonyms = null,Object? antonyms = null,}) {
  return _then(_self.copyWith(
definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as String,example: freezed == example ? _self.example : example // ignore: cast_nullable_to_non_nullable
as String?,synonyms: null == synonyms ? _self.synonyms : synonyms // ignore: cast_nullable_to_non_nullable
as List<String>,antonyms: null == antonyms ? _self.antonyms : antonyms // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Definition].
extension DefinitionPatterns on Definition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Definition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Definition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Definition value)  $default,){
final _that = this;
switch (_that) {
case _Definition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Definition value)?  $default,){
final _that = this;
switch (_that) {
case _Definition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String definition,  String? example,  List<String> synonyms,  List<String> antonyms)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Definition() when $default != null:
return $default(_that.definition,_that.example,_that.synonyms,_that.antonyms);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String definition,  String? example,  List<String> synonyms,  List<String> antonyms)  $default,) {final _that = this;
switch (_that) {
case _Definition():
return $default(_that.definition,_that.example,_that.synonyms,_that.antonyms);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String definition,  String? example,  List<String> synonyms,  List<String> antonyms)?  $default,) {final _that = this;
switch (_that) {
case _Definition() when $default != null:
return $default(_that.definition,_that.example,_that.synonyms,_that.antonyms);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Definition implements Definition {
  const _Definition({required this.definition, this.example, final  List<String> synonyms = const [], final  List<String> antonyms = const []}): _synonyms = synonyms,_antonyms = antonyms;
  factory _Definition.fromJson(Map<String, dynamic> json) => _$DefinitionFromJson(json);

@override final  String definition;
@override final  String? example;
 final  List<String> _synonyms;
@override@JsonKey() List<String> get synonyms {
  if (_synonyms is EqualUnmodifiableListView) return _synonyms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_synonyms);
}

 final  List<String> _antonyms;
@override@JsonKey() List<String> get antonyms {
  if (_antonyms is EqualUnmodifiableListView) return _antonyms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_antonyms);
}


/// Create a copy of Definition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DefinitionCopyWith<_Definition> get copyWith => __$DefinitionCopyWithImpl<_Definition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DefinitionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Definition&&(identical(other.definition, definition) || other.definition == definition)&&(identical(other.example, example) || other.example == example)&&const DeepCollectionEquality().equals(other._synonyms, _synonyms)&&const DeepCollectionEquality().equals(other._antonyms, _antonyms));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,definition,example,const DeepCollectionEquality().hash(_synonyms),const DeepCollectionEquality().hash(_antonyms));

@override
String toString() {
  return 'Definition(definition: $definition, example: $example, synonyms: $synonyms, antonyms: $antonyms)';
}


}

/// @nodoc
abstract mixin class _$DefinitionCopyWith<$Res> implements $DefinitionCopyWith<$Res> {
  factory _$DefinitionCopyWith(_Definition value, $Res Function(_Definition) _then) = __$DefinitionCopyWithImpl;
@override @useResult
$Res call({
 String definition, String? example, List<String> synonyms, List<String> antonyms
});




}
/// @nodoc
class __$DefinitionCopyWithImpl<$Res>
    implements _$DefinitionCopyWith<$Res> {
  __$DefinitionCopyWithImpl(this._self, this._then);

  final _Definition _self;
  final $Res Function(_Definition) _then;

/// Create a copy of Definition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? definition = null,Object? example = freezed,Object? synonyms = null,Object? antonyms = null,}) {
  return _then(_Definition(
definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as String,example: freezed == example ? _self.example : example // ignore: cast_nullable_to_non_nullable
as String?,synonyms: null == synonyms ? _self._synonyms : synonyms // ignore: cast_nullable_to_non_nullable
as List<String>,antonyms: null == antonyms ? _self._antonyms : antonyms // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$Meaning {

 String get partOfSpeech; List<Definition> get definitions; List<String> get synonyms; List<String> get antonyms;
/// Create a copy of Meaning
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MeaningCopyWith<Meaning> get copyWith => _$MeaningCopyWithImpl<Meaning>(this as Meaning, _$identity);

  /// Serializes this Meaning to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Meaning&&(identical(other.partOfSpeech, partOfSpeech) || other.partOfSpeech == partOfSpeech)&&const DeepCollectionEquality().equals(other.definitions, definitions)&&const DeepCollectionEquality().equals(other.synonyms, synonyms)&&const DeepCollectionEquality().equals(other.antonyms, antonyms));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,partOfSpeech,const DeepCollectionEquality().hash(definitions),const DeepCollectionEquality().hash(synonyms),const DeepCollectionEquality().hash(antonyms));

@override
String toString() {
  return 'Meaning(partOfSpeech: $partOfSpeech, definitions: $definitions, synonyms: $synonyms, antonyms: $antonyms)';
}


}

/// @nodoc
abstract mixin class $MeaningCopyWith<$Res>  {
  factory $MeaningCopyWith(Meaning value, $Res Function(Meaning) _then) = _$MeaningCopyWithImpl;
@useResult
$Res call({
 String partOfSpeech, List<Definition> definitions, List<String> synonyms, List<String> antonyms
});




}
/// @nodoc
class _$MeaningCopyWithImpl<$Res>
    implements $MeaningCopyWith<$Res> {
  _$MeaningCopyWithImpl(this._self, this._then);

  final Meaning _self;
  final $Res Function(Meaning) _then;

/// Create a copy of Meaning
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? partOfSpeech = null,Object? definitions = null,Object? synonyms = null,Object? antonyms = null,}) {
  return _then(_self.copyWith(
partOfSpeech: null == partOfSpeech ? _self.partOfSpeech : partOfSpeech // ignore: cast_nullable_to_non_nullable
as String,definitions: null == definitions ? _self.definitions : definitions // ignore: cast_nullable_to_non_nullable
as List<Definition>,synonyms: null == synonyms ? _self.synonyms : synonyms // ignore: cast_nullable_to_non_nullable
as List<String>,antonyms: null == antonyms ? _self.antonyms : antonyms // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Meaning].
extension MeaningPatterns on Meaning {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Meaning value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Meaning() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Meaning value)  $default,){
final _that = this;
switch (_that) {
case _Meaning():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Meaning value)?  $default,){
final _that = this;
switch (_that) {
case _Meaning() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String partOfSpeech,  List<Definition> definitions,  List<String> synonyms,  List<String> antonyms)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Meaning() when $default != null:
return $default(_that.partOfSpeech,_that.definitions,_that.synonyms,_that.antonyms);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String partOfSpeech,  List<Definition> definitions,  List<String> synonyms,  List<String> antonyms)  $default,) {final _that = this;
switch (_that) {
case _Meaning():
return $default(_that.partOfSpeech,_that.definitions,_that.synonyms,_that.antonyms);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String partOfSpeech,  List<Definition> definitions,  List<String> synonyms,  List<String> antonyms)?  $default,) {final _that = this;
switch (_that) {
case _Meaning() when $default != null:
return $default(_that.partOfSpeech,_that.definitions,_that.synonyms,_that.antonyms);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Meaning implements Meaning {
  const _Meaning({required this.partOfSpeech, final  List<Definition> definitions = const [], final  List<String> synonyms = const [], final  List<String> antonyms = const []}): _definitions = definitions,_synonyms = synonyms,_antonyms = antonyms;
  factory _Meaning.fromJson(Map<String, dynamic> json) => _$MeaningFromJson(json);

@override final  String partOfSpeech;
 final  List<Definition> _definitions;
@override@JsonKey() List<Definition> get definitions {
  if (_definitions is EqualUnmodifiableListView) return _definitions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_definitions);
}

 final  List<String> _synonyms;
@override@JsonKey() List<String> get synonyms {
  if (_synonyms is EqualUnmodifiableListView) return _synonyms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_synonyms);
}

 final  List<String> _antonyms;
@override@JsonKey() List<String> get antonyms {
  if (_antonyms is EqualUnmodifiableListView) return _antonyms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_antonyms);
}


/// Create a copy of Meaning
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MeaningCopyWith<_Meaning> get copyWith => __$MeaningCopyWithImpl<_Meaning>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MeaningToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Meaning&&(identical(other.partOfSpeech, partOfSpeech) || other.partOfSpeech == partOfSpeech)&&const DeepCollectionEquality().equals(other._definitions, _definitions)&&const DeepCollectionEquality().equals(other._synonyms, _synonyms)&&const DeepCollectionEquality().equals(other._antonyms, _antonyms));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,partOfSpeech,const DeepCollectionEquality().hash(_definitions),const DeepCollectionEquality().hash(_synonyms),const DeepCollectionEquality().hash(_antonyms));

@override
String toString() {
  return 'Meaning(partOfSpeech: $partOfSpeech, definitions: $definitions, synonyms: $synonyms, antonyms: $antonyms)';
}


}

/// @nodoc
abstract mixin class _$MeaningCopyWith<$Res> implements $MeaningCopyWith<$Res> {
  factory _$MeaningCopyWith(_Meaning value, $Res Function(_Meaning) _then) = __$MeaningCopyWithImpl;
@override @useResult
$Res call({
 String partOfSpeech, List<Definition> definitions, List<String> synonyms, List<String> antonyms
});




}
/// @nodoc
class __$MeaningCopyWithImpl<$Res>
    implements _$MeaningCopyWith<$Res> {
  __$MeaningCopyWithImpl(this._self, this._then);

  final _Meaning _self;
  final $Res Function(_Meaning) _then;

/// Create a copy of Meaning
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? partOfSpeech = null,Object? definitions = null,Object? synonyms = null,Object? antonyms = null,}) {
  return _then(_Meaning(
partOfSpeech: null == partOfSpeech ? _self.partOfSpeech : partOfSpeech // ignore: cast_nullable_to_non_nullable
as String,definitions: null == definitions ? _self._definitions : definitions // ignore: cast_nullable_to_non_nullable
as List<Definition>,synonyms: null == synonyms ? _self._synonyms : synonyms // ignore: cast_nullable_to_non_nullable
as List<String>,antonyms: null == antonyms ? _self._antonyms : antonyms // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$WordDetail {

 int get id; String get word; String? get phonetic; List<Phonetic> get phonetics; List<Meaning> get meanings; String? get licenseName; String? get licenseUrl; List<String> get sourceUrls;
/// Create a copy of WordDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WordDetailCopyWith<WordDetail> get copyWith => _$WordDetailCopyWithImpl<WordDetail>(this as WordDetail, _$identity);

  /// Serializes this WordDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WordDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.word, word) || other.word == word)&&(identical(other.phonetic, phonetic) || other.phonetic == phonetic)&&const DeepCollectionEquality().equals(other.phonetics, phonetics)&&const DeepCollectionEquality().equals(other.meanings, meanings)&&(identical(other.licenseName, licenseName) || other.licenseName == licenseName)&&(identical(other.licenseUrl, licenseUrl) || other.licenseUrl == licenseUrl)&&const DeepCollectionEquality().equals(other.sourceUrls, sourceUrls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,word,phonetic,const DeepCollectionEquality().hash(phonetics),const DeepCollectionEquality().hash(meanings),licenseName,licenseUrl,const DeepCollectionEquality().hash(sourceUrls));

@override
String toString() {
  return 'WordDetail(id: $id, word: $word, phonetic: $phonetic, phonetics: $phonetics, meanings: $meanings, licenseName: $licenseName, licenseUrl: $licenseUrl, sourceUrls: $sourceUrls)';
}


}

/// @nodoc
abstract mixin class $WordDetailCopyWith<$Res>  {
  factory $WordDetailCopyWith(WordDetail value, $Res Function(WordDetail) _then) = _$WordDetailCopyWithImpl;
@useResult
$Res call({
 int id, String word, String? phonetic, List<Phonetic> phonetics, List<Meaning> meanings, String? licenseName, String? licenseUrl, List<String> sourceUrls
});




}
/// @nodoc
class _$WordDetailCopyWithImpl<$Res>
    implements $WordDetailCopyWith<$Res> {
  _$WordDetailCopyWithImpl(this._self, this._then);

  final WordDetail _self;
  final $Res Function(WordDetail) _then;

/// Create a copy of WordDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? word = null,Object? phonetic = freezed,Object? phonetics = null,Object? meanings = null,Object? licenseName = freezed,Object? licenseUrl = freezed,Object? sourceUrls = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,word: null == word ? _self.word : word // ignore: cast_nullable_to_non_nullable
as String,phonetic: freezed == phonetic ? _self.phonetic : phonetic // ignore: cast_nullable_to_non_nullable
as String?,phonetics: null == phonetics ? _self.phonetics : phonetics // ignore: cast_nullable_to_non_nullable
as List<Phonetic>,meanings: null == meanings ? _self.meanings : meanings // ignore: cast_nullable_to_non_nullable
as List<Meaning>,licenseName: freezed == licenseName ? _self.licenseName : licenseName // ignore: cast_nullable_to_non_nullable
as String?,licenseUrl: freezed == licenseUrl ? _self.licenseUrl : licenseUrl // ignore: cast_nullable_to_non_nullable
as String?,sourceUrls: null == sourceUrls ? _self.sourceUrls : sourceUrls // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [WordDetail].
extension WordDetailPatterns on WordDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WordDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WordDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WordDetail value)  $default,){
final _that = this;
switch (_that) {
case _WordDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WordDetail value)?  $default,){
final _that = this;
switch (_that) {
case _WordDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String word,  String? phonetic,  List<Phonetic> phonetics,  List<Meaning> meanings,  String? licenseName,  String? licenseUrl,  List<String> sourceUrls)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WordDetail() when $default != null:
return $default(_that.id,_that.word,_that.phonetic,_that.phonetics,_that.meanings,_that.licenseName,_that.licenseUrl,_that.sourceUrls);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String word,  String? phonetic,  List<Phonetic> phonetics,  List<Meaning> meanings,  String? licenseName,  String? licenseUrl,  List<String> sourceUrls)  $default,) {final _that = this;
switch (_that) {
case _WordDetail():
return $default(_that.id,_that.word,_that.phonetic,_that.phonetics,_that.meanings,_that.licenseName,_that.licenseUrl,_that.sourceUrls);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String word,  String? phonetic,  List<Phonetic> phonetics,  List<Meaning> meanings,  String? licenseName,  String? licenseUrl,  List<String> sourceUrls)?  $default,) {final _that = this;
switch (_that) {
case _WordDetail() when $default != null:
return $default(_that.id,_that.word,_that.phonetic,_that.phonetics,_that.meanings,_that.licenseName,_that.licenseUrl,_that.sourceUrls);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WordDetail implements WordDetail {
  const _WordDetail({required this.id, required this.word, this.phonetic, final  List<Phonetic> phonetics = const [], final  List<Meaning> meanings = const [], this.licenseName, this.licenseUrl, final  List<String> sourceUrls = const []}): _phonetics = phonetics,_meanings = meanings,_sourceUrls = sourceUrls;
  factory _WordDetail.fromJson(Map<String, dynamic> json) => _$WordDetailFromJson(json);

@override final  int id;
@override final  String word;
@override final  String? phonetic;
 final  List<Phonetic> _phonetics;
@override@JsonKey() List<Phonetic> get phonetics {
  if (_phonetics is EqualUnmodifiableListView) return _phonetics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_phonetics);
}

 final  List<Meaning> _meanings;
@override@JsonKey() List<Meaning> get meanings {
  if (_meanings is EqualUnmodifiableListView) return _meanings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_meanings);
}

@override final  String? licenseName;
@override final  String? licenseUrl;
 final  List<String> _sourceUrls;
@override@JsonKey() List<String> get sourceUrls {
  if (_sourceUrls is EqualUnmodifiableListView) return _sourceUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sourceUrls);
}


/// Create a copy of WordDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WordDetailCopyWith<_WordDetail> get copyWith => __$WordDetailCopyWithImpl<_WordDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WordDetailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WordDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.word, word) || other.word == word)&&(identical(other.phonetic, phonetic) || other.phonetic == phonetic)&&const DeepCollectionEquality().equals(other._phonetics, _phonetics)&&const DeepCollectionEquality().equals(other._meanings, _meanings)&&(identical(other.licenseName, licenseName) || other.licenseName == licenseName)&&(identical(other.licenseUrl, licenseUrl) || other.licenseUrl == licenseUrl)&&const DeepCollectionEquality().equals(other._sourceUrls, _sourceUrls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,word,phonetic,const DeepCollectionEquality().hash(_phonetics),const DeepCollectionEquality().hash(_meanings),licenseName,licenseUrl,const DeepCollectionEquality().hash(_sourceUrls));

@override
String toString() {
  return 'WordDetail(id: $id, word: $word, phonetic: $phonetic, phonetics: $phonetics, meanings: $meanings, licenseName: $licenseName, licenseUrl: $licenseUrl, sourceUrls: $sourceUrls)';
}


}

/// @nodoc
abstract mixin class _$WordDetailCopyWith<$Res> implements $WordDetailCopyWith<$Res> {
  factory _$WordDetailCopyWith(_WordDetail value, $Res Function(_WordDetail) _then) = __$WordDetailCopyWithImpl;
@override @useResult
$Res call({
 int id, String word, String? phonetic, List<Phonetic> phonetics, List<Meaning> meanings, String? licenseName, String? licenseUrl, List<String> sourceUrls
});




}
/// @nodoc
class __$WordDetailCopyWithImpl<$Res>
    implements _$WordDetailCopyWith<$Res> {
  __$WordDetailCopyWithImpl(this._self, this._then);

  final _WordDetail _self;
  final $Res Function(_WordDetail) _then;

/// Create a copy of WordDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? word = null,Object? phonetic = freezed,Object? phonetics = null,Object? meanings = null,Object? licenseName = freezed,Object? licenseUrl = freezed,Object? sourceUrls = null,}) {
  return _then(_WordDetail(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,word: null == word ? _self.word : word // ignore: cast_nullable_to_non_nullable
as String,phonetic: freezed == phonetic ? _self.phonetic : phonetic // ignore: cast_nullable_to_non_nullable
as String?,phonetics: null == phonetics ? _self._phonetics : phonetics // ignore: cast_nullable_to_non_nullable
as List<Phonetic>,meanings: null == meanings ? _self._meanings : meanings // ignore: cast_nullable_to_non_nullable
as List<Meaning>,licenseName: freezed == licenseName ? _self.licenseName : licenseName // ignore: cast_nullable_to_non_nullable
as String?,licenseUrl: freezed == licenseUrl ? _self.licenseUrl : licenseUrl // ignore: cast_nullable_to_non_nullable
as String?,sourceUrls: null == sourceUrls ? _self._sourceUrls : sourceUrls // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$WordSummary {

 int get id; String get word; String? get phonetic;
/// Create a copy of WordSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WordSummaryCopyWith<WordSummary> get copyWith => _$WordSummaryCopyWithImpl<WordSummary>(this as WordSummary, _$identity);

  /// Serializes this WordSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WordSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.word, word) || other.word == word)&&(identical(other.phonetic, phonetic) || other.phonetic == phonetic));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,word,phonetic);

@override
String toString() {
  return 'WordSummary(id: $id, word: $word, phonetic: $phonetic)';
}


}

/// @nodoc
abstract mixin class $WordSummaryCopyWith<$Res>  {
  factory $WordSummaryCopyWith(WordSummary value, $Res Function(WordSummary) _then) = _$WordSummaryCopyWithImpl;
@useResult
$Res call({
 int id, String word, String? phonetic
});




}
/// @nodoc
class _$WordSummaryCopyWithImpl<$Res>
    implements $WordSummaryCopyWith<$Res> {
  _$WordSummaryCopyWithImpl(this._self, this._then);

  final WordSummary _self;
  final $Res Function(WordSummary) _then;

/// Create a copy of WordSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? word = null,Object? phonetic = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,word: null == word ? _self.word : word // ignore: cast_nullable_to_non_nullable
as String,phonetic: freezed == phonetic ? _self.phonetic : phonetic // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WordSummary].
extension WordSummaryPatterns on WordSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WordSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WordSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WordSummary value)  $default,){
final _that = this;
switch (_that) {
case _WordSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WordSummary value)?  $default,){
final _that = this;
switch (_that) {
case _WordSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String word,  String? phonetic)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WordSummary() when $default != null:
return $default(_that.id,_that.word,_that.phonetic);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String word,  String? phonetic)  $default,) {final _that = this;
switch (_that) {
case _WordSummary():
return $default(_that.id,_that.word,_that.phonetic);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String word,  String? phonetic)?  $default,) {final _that = this;
switch (_that) {
case _WordSummary() when $default != null:
return $default(_that.id,_that.word,_that.phonetic);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WordSummary implements WordSummary {
  const _WordSummary({required this.id, required this.word, this.phonetic});
  factory _WordSummary.fromJson(Map<String, dynamic> json) => _$WordSummaryFromJson(json);

@override final  int id;
@override final  String word;
@override final  String? phonetic;

/// Create a copy of WordSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WordSummaryCopyWith<_WordSummary> get copyWith => __$WordSummaryCopyWithImpl<_WordSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WordSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WordSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.word, word) || other.word == word)&&(identical(other.phonetic, phonetic) || other.phonetic == phonetic));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,word,phonetic);

@override
String toString() {
  return 'WordSummary(id: $id, word: $word, phonetic: $phonetic)';
}


}

/// @nodoc
abstract mixin class _$WordSummaryCopyWith<$Res> implements $WordSummaryCopyWith<$Res> {
  factory _$WordSummaryCopyWith(_WordSummary value, $Res Function(_WordSummary) _then) = __$WordSummaryCopyWithImpl;
@override @useResult
$Res call({
 int id, String word, String? phonetic
});




}
/// @nodoc
class __$WordSummaryCopyWithImpl<$Res>
    implements _$WordSummaryCopyWith<$Res> {
  __$WordSummaryCopyWithImpl(this._self, this._then);

  final _WordSummary _self;
  final $Res Function(_WordSummary) _then;

/// Create a copy of WordSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? word = null,Object? phonetic = freezed,}) {
  return _then(_WordSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,word: null == word ? _self.word : word // ignore: cast_nullable_to_non_nullable
as String,phonetic: freezed == phonetic ? _self.phonetic : phonetic // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
