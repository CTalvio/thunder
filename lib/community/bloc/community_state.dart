part of 'community_bloc.dart';

enum CommunityStatus { initial, loading, refreshing, success, empty, networkFailure, failure }

class CommunityState extends Equatable {
  const CommunityState({
    this.status = CommunityStatus.initial,
    this.postViews = const [],
    this.page = 1,
    this.errorMessage,
    this.listingType = ListingType.Local,
    this.communityId,
    this.hasReachedEnd = false,
    this.subscribedType,
    this.sortType,
    this.communityName,
    this.communityInfo,
  });

  final CommunityStatus status;
  final ListingType? listingType;
  final SortType? sortType;

  final int page;
  final List<PostViewMedia>? postViews;

  final String? errorMessage;

  // Specifies the community we are loading for
  final int? communityId;
  final String? communityName;
  final GetCommunityResponse? communityInfo;

  final bool hasReachedEnd;
  final SubscribedType? subscribedType;

  CommunityState copyWith({
    CommunityStatus? status,
    int? page,
    List<PostViewMedia>? postViews,
    String? errorMessage,
    ListingType? listingType,
    int? communityId,
    bool? hasReachedEnd,
    SubscribedType? subscribedType,
    SortType? sortType,
    String? communityName,
    GetCommunityResponse? communityInfo,
  }) {
    return CommunityState(
      status: status ?? this.status,
      page: page ?? this.page,
      postViews: postViews ?? this.postViews,
      errorMessage: errorMessage ?? this.errorMessage,
      listingType: listingType,
      communityId: communityId,
      communityName: communityName,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      subscribedType: subscribedType ?? this.subscribedType,
      sortType: sortType ?? this.sortType,
      communityInfo: communityInfo ?? this.communityInfo,
    );
  }

  @override
  List<Object?> get props => [status, page, postViews, errorMessage, listingType, communityId, hasReachedEnd, subscribedType, sortType];
}
