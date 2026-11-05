// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dictionary_topic_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DictionaryTopicState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DictionaryTopicState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DictionaryTopicState()';
}


}

/// @nodoc
class $DictionaryTopicStateCopyWith<$Res>  {
$DictionaryTopicStateCopyWith(DictionaryTopicState _, $Res Function(DictionaryTopicState) __);
}


/// Adds pattern-matching-related methods to [DictionaryTopicState].
extension DictionaryTopicStatePatterns on DictionaryTopicState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Initial value)?  initial,TResult Function( _LoadingTopics value)?  loadingTopics,TResult Function( _TopicsLoaded value)?  topicsLoaded,TResult Function( _LoadingWords value)?  loadingWords,TResult Function( _WordsLoaded value)?  wordsLoaded,TResult Function( _Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Initial() when initial != null:
return initial(_that);case _LoadingTopics() when loadingTopics != null:
return loadingTopics(_that);case _TopicsLoaded() when topicsLoaded != null:
return topicsLoaded(_that);case _LoadingWords() when loadingWords != null:
return loadingWords(_that);case _WordsLoaded() when wordsLoaded != null:
return wordsLoaded(_that);case _Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Initial value)  initial,required TResult Function( _LoadingTopics value)  loadingTopics,required TResult Function( _TopicsLoaded value)  topicsLoaded,required TResult Function( _LoadingWords value)  loadingWords,required TResult Function( _WordsLoaded value)  wordsLoaded,required TResult Function( _Error value)  error,}){
final _that = this;
switch (_that) {
case _Initial():
return initial(_that);case _LoadingTopics():
return loadingTopics(_that);case _TopicsLoaded():
return topicsLoaded(_that);case _LoadingWords():
return loadingWords(_that);case _WordsLoaded():
return wordsLoaded(_that);case _Error():
return error(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Initial value)?  initial,TResult? Function( _LoadingTopics value)?  loadingTopics,TResult? Function( _TopicsLoaded value)?  topicsLoaded,TResult? Function( _LoadingWords value)?  loadingWords,TResult? Function( _WordsLoaded value)?  wordsLoaded,TResult? Function( _Error value)?  error,}){
final _that = this;
switch (_that) {
case _Initial() when initial != null:
return initial(_that);case _LoadingTopics() when loadingTopics != null:
return loadingTopics(_that);case _TopicsLoaded() when topicsLoaded != null:
return topicsLoaded(_that);case _LoadingWords() when loadingWords != null:
return loadingWords(_that);case _WordsLoaded() when wordsLoaded != null:
return wordsLoaded(_that);case _Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initial,TResult Function()?  loadingTopics,TResult Function( List<DictionaryTopic> topics)?  topicsLoaded,TResult Function( List<DictionaryTopic> topics,  DictionaryTopic selectedTopic)?  loadingWords,TResult Function( List<DictionaryTopic> topics,  DictionaryTopic selectedTopic,  List<WordSummary> words,  int currentPage,  int totalPages,  bool isLoadingMore)?  wordsLoaded,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Initial() when initial != null:
return initial();case _LoadingTopics() when loadingTopics != null:
return loadingTopics();case _TopicsLoaded() when topicsLoaded != null:
return topicsLoaded(_that.topics);case _LoadingWords() when loadingWords != null:
return loadingWords(_that.topics,_that.selectedTopic);case _WordsLoaded() when wordsLoaded != null:
return wordsLoaded(_that.topics,_that.selectedTopic,_that.words,_that.currentPage,_that.totalPages,_that.isLoadingMore);case _Error() when error != null:
return error(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initial,required TResult Function()  loadingTopics,required TResult Function( List<DictionaryTopic> topics)  topicsLoaded,required TResult Function( List<DictionaryTopic> topics,  DictionaryTopic selectedTopic)  loadingWords,required TResult Function( List<DictionaryTopic> topics,  DictionaryTopic selectedTopic,  List<WordSummary> words,  int currentPage,  int totalPages,  bool isLoadingMore)  wordsLoaded,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case _Initial():
return initial();case _LoadingTopics():
return loadingTopics();case _TopicsLoaded():
return topicsLoaded(_that.topics);case _LoadingWords():
return loadingWords(_that.topics,_that.selectedTopic);case _WordsLoaded():
return wordsLoaded(_that.topics,_that.selectedTopic,_that.words,_that.currentPage,_that.totalPages,_that.isLoadingMore);case _Error():
return error(_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initial,TResult? Function()?  loadingTopics,TResult? Function( List<DictionaryTopic> topics)?  topicsLoaded,TResult? Function( List<DictionaryTopic> topics,  DictionaryTopic selectedTopic)?  loadingWords,TResult? Function( List<DictionaryTopic> topics,  DictionaryTopic selectedTopic,  List<WordSummary> words,  int currentPage,  int totalPages,  bool isLoadingMore)?  wordsLoaded,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case _Initial() when initial != null:
return initial();case _LoadingTopics() when loadingTopics != null:
return loadingTopics();case _TopicsLoaded() when topicsLoaded != null:
return topicsLoaded(_that.topics);case _LoadingWords() when loadingWords != null:
return loadingWords(_that.topics,_that.selectedTopic);case _WordsLoaded() when wordsLoaded != null:
return wordsLoaded(_that.topics,_that.selectedTopic,_that.words,_that.currentPage,_that.totalPages,_that.isLoadingMore);case _Error() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _Initial implements DictionaryTopicState {
  const _Initial();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Initial);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DictionaryTopicState.initial()';
}


}




/// @nodoc


class _LoadingTopics implements DictionaryTopicState {
  const _LoadingTopics();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoadingTopics);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DictionaryTopicState.loadingTopics()';
}


}




/// @nodoc


class _TopicsLoaded implements DictionaryTopicState {
  const _TopicsLoaded(final  List<DictionaryTopic> topics): _topics = topics;
  

 final  List<DictionaryTopic> _topics;
 List<DictionaryTopic> get topics {
  if (_topics is EqualUnmodifiableListView) return _topics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topics);
}


/// Create a copy of DictionaryTopicState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopicsLoadedCopyWith<_TopicsLoaded> get copyWith => __$TopicsLoadedCopyWithImpl<_TopicsLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TopicsLoaded&&const DeepCollectionEquality().equals(other._topics, _topics));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_topics));

@override
String toString() {
  return 'DictionaryTopicState.topicsLoaded(topics: $topics)';
}


}

/// @nodoc
abstract mixin class _$TopicsLoadedCopyWith<$Res> implements $DictionaryTopicStateCopyWith<$Res> {
  factory _$TopicsLoadedCopyWith(_TopicsLoaded value, $Res Function(_TopicsLoaded) _then) = __$TopicsLoadedCopyWithImpl;
@useResult
$Res call({
 List<DictionaryTopic> topics
});




}
/// @nodoc
class __$TopicsLoadedCopyWithImpl<$Res>
    implements _$TopicsLoadedCopyWith<$Res> {
  __$TopicsLoadedCopyWithImpl(this._self, this._then);

  final _TopicsLoaded _self;
  final $Res Function(_TopicsLoaded) _then;

/// Create a copy of DictionaryTopicState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? topics = null,}) {
  return _then(_TopicsLoaded(
null == topics ? _self._topics : topics // ignore: cast_nullable_to_non_nullable
as List<DictionaryTopic>,
  ));
}


}

/// @nodoc


class _LoadingWords implements DictionaryTopicState {
  const _LoadingWords({required final  List<DictionaryTopic> topics, required this.selectedTopic}): _topics = topics;
  

 final  List<DictionaryTopic> _topics;
 List<DictionaryTopic> get topics {
  if (_topics is EqualUnmodifiableListView) return _topics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topics);
}

 final  DictionaryTopic selectedTopic;

/// Create a copy of DictionaryTopicState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoadingWordsCopyWith<_LoadingWords> get copyWith => __$LoadingWordsCopyWithImpl<_LoadingWords>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoadingWords&&const DeepCollectionEquality().equals(other._topics, _topics)&&(identical(other.selectedTopic, selectedTopic) || other.selectedTopic == selectedTopic));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_topics),selectedTopic);

@override
String toString() {
  return 'DictionaryTopicState.loadingWords(topics: $topics, selectedTopic: $selectedTopic)';
}


}

/// @nodoc
abstract mixin class _$LoadingWordsCopyWith<$Res> implements $DictionaryTopicStateCopyWith<$Res> {
  factory _$LoadingWordsCopyWith(_LoadingWords value, $Res Function(_LoadingWords) _then) = __$LoadingWordsCopyWithImpl;
@useResult
$Res call({
 List<DictionaryTopic> topics, DictionaryTopic selectedTopic
});


$DictionaryTopicCopyWith<$Res> get selectedTopic;

}
/// @nodoc
class __$LoadingWordsCopyWithImpl<$Res>
    implements _$LoadingWordsCopyWith<$Res> {
  __$LoadingWordsCopyWithImpl(this._self, this._then);

  final _LoadingWords _self;
  final $Res Function(_LoadingWords) _then;

/// Create a copy of DictionaryTopicState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? topics = null,Object? selectedTopic = null,}) {
  return _then(_LoadingWords(
topics: null == topics ? _self._topics : topics // ignore: cast_nullable_to_non_nullable
as List<DictionaryTopic>,selectedTopic: null == selectedTopic ? _self.selectedTopic : selectedTopic // ignore: cast_nullable_to_non_nullable
as DictionaryTopic,
  ));
}

/// Create a copy of DictionaryTopicState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DictionaryTopicCopyWith<$Res> get selectedTopic {
  
  return $DictionaryTopicCopyWith<$Res>(_self.selectedTopic, (value) {
    return _then(_self.copyWith(selectedTopic: value));
  });
}
}

/// @nodoc


class _WordsLoaded implements DictionaryTopicState {
  const _WordsLoaded({required final  List<DictionaryTopic> topics, required this.selectedTopic, required final  List<WordSummary> words, required this.currentPage, required this.totalPages, this.isLoadingMore = false}): _topics = topics,_words = words;
  

 final  List<DictionaryTopic> _topics;
 List<DictionaryTopic> get topics {
  if (_topics is EqualUnmodifiableListView) return _topics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topics);
}

 final  DictionaryTopic selectedTopic;
 final  List<WordSummary> _words;
 List<WordSummary> get words {
  if (_words is EqualUnmodifiableListView) return _words;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_words);
}

 final  int currentPage;
 final  int totalPages;
@JsonKey() final  bool isLoadingMore;

/// Create a copy of DictionaryTopicState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WordsLoadedCopyWith<_WordsLoaded> get copyWith => __$WordsLoadedCopyWithImpl<_WordsLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WordsLoaded&&const DeepCollectionEquality().equals(other._topics, _topics)&&(identical(other.selectedTopic, selectedTopic) || other.selectedTopic == selectedTopic)&&const DeepCollectionEquality().equals(other._words, _words)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages)&&(identical(other.isLoadingMore, isLoadingMore) || other.isLoadingMore == isLoadingMore));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_topics),selectedTopic,const DeepCollectionEquality().hash(_words),currentPage,totalPages,isLoadingMore);

@override
String toString() {
  return 'DictionaryTopicState.wordsLoaded(topics: $topics, selectedTopic: $selectedTopic, words: $words, currentPage: $currentPage, totalPages: $totalPages, isLoadingMore: $isLoadingMore)';
}


}

/// @nodoc
abstract mixin class _$WordsLoadedCopyWith<$Res> implements $DictionaryTopicStateCopyWith<$Res> {
  factory _$WordsLoadedCopyWith(_WordsLoaded value, $Res Function(_WordsLoaded) _then) = __$WordsLoadedCopyWithImpl;
@useResult
$Res call({
 List<DictionaryTopic> topics, DictionaryTopic selectedTopic, List<WordSummary> words, int currentPage, int totalPages, bool isLoadingMore
});


$DictionaryTopicCopyWith<$Res> get selectedTopic;

}
/// @nodoc
class __$WordsLoadedCopyWithImpl<$Res>
    implements _$WordsLoadedCopyWith<$Res> {
  __$WordsLoadedCopyWithImpl(this._self, this._then);

  final _WordsLoaded _self;
  final $Res Function(_WordsLoaded) _then;

/// Create a copy of DictionaryTopicState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? topics = null,Object? selectedTopic = null,Object? words = null,Object? currentPage = null,Object? totalPages = null,Object? isLoadingMore = null,}) {
  return _then(_WordsLoaded(
topics: null == topics ? _self._topics : topics // ignore: cast_nullable_to_non_nullable
as List<DictionaryTopic>,selectedTopic: null == selectedTopic ? _self.selectedTopic : selectedTopic // ignore: cast_nullable_to_non_nullable
as DictionaryTopic,words: null == words ? _self._words : words // ignore: cast_nullable_to_non_nullable
as List<WordSummary>,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,isLoadingMore: null == isLoadingMore ? _self.isLoadingMore : isLoadingMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of DictionaryTopicState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DictionaryTopicCopyWith<$Res> get selectedTopic {
  
  return $DictionaryTopicCopyWith<$Res>(_self.selectedTopic, (value) {
    return _then(_self.copyWith(selectedTopic: value));
  });
}
}

/// @nodoc


class _Error implements DictionaryTopicState {
  const _Error(this.message);
  

 final  String message;

/// Create a copy of DictionaryTopicState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ErrorCopyWith<_Error> get copyWith => __$ErrorCopyWithImpl<_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Error&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'DictionaryTopicState.error(message: $message)';
}


}

/// @nodoc
abstract mixin class _$ErrorCopyWith<$Res> implements $DictionaryTopicStateCopyWith<$Res> {
  factory _$ErrorCopyWith(_Error value, $Res Function(_Error) _then) = __$ErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class __$ErrorCopyWithImpl<$Res>
    implements _$ErrorCopyWith<$Res> {
  __$ErrorCopyWithImpl(this._self, this._then);

  final _Error _self;
  final $Res Function(_Error) _then;

/// Create a copy of DictionaryTopicState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(_Error(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
