import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:stream_transform/stream_transform.dart';

import 'package:lemmy/lemmy.dart';
import 'package:thunder/account/models/account.dart';
import 'package:thunder/core/auth/helpers/fetch_account.dart';
import 'package:thunder/core/models/post_view_media.dart';

import 'package:thunder/utils/comment.dart';
import 'package:thunder/core/models/comment_view_tree.dart';
import 'package:thunder/core/singletons/lemmy_client.dart';
import 'package:thunder/utils/post.dart';

part 'post_event.dart';
part 'post_state.dart';

const throttleDuration = Duration(seconds: 1);
const timeout = Duration(seconds: 3);

EventTransformer<E> throttleDroppable<E>(Duration duration) {
  return (events, mapper) => droppable<E>().call(events.throttle(duration), mapper);
}

class PostBloc extends Bloc<PostEvent, PostState> {
  PostBloc() : super(const PostState()) {
    on<GetPostEvent>(
      _getPostEvent,
      transformer: throttleDroppable(throttleDuration),
    );
    on<GetPostCommentsEvent>(
      _getPostCommentsEvent,
      transformer: throttleDroppable(throttleDuration),
    );
    on<VotePostEvent>(
      _votePostEvent,
      transformer: throttleDroppable(throttleDuration),
    );
    on<SavePostEvent>(
      _savePostEvent,
      transformer: throttleDroppable(throttleDuration),
    );
    on<VoteCommentEvent>(
      _voteCommentEvent,
      transformer: throttleDroppable(throttleDuration),
    );
    on<SaveCommentEvent>(
      _saveCommentEvent,
      transformer: throttleDroppable(throttleDuration),
    );
    on<CreateCommentEvent>(
      _createCommentEvent,
      transformer: throttleDroppable(throttleDuration),
    );
  }

  Future<void> _getPostEvent(GetPostEvent event, emit) async {
    try {
      emit(state.copyWith(status: PostStatus.loading));

      Account? account = await fetchActiveProfileAccount();
      Lemmy lemmy = LemmyClient.instance.lemmy;

      GetPostResponse? getPostResponse;

      if (event.postId != null) {
        getPostResponse = await lemmy
            .getPost(
          GetPost(
            id: event.postId,
            auth: account?.jwt,
          ),
        )
            .timeout(timeout, onTimeout: () {
          throw Exception('Error: Timeout when attempting to fetch post');
        });
      }

      PostViewMedia? postView = event.postView;

      if (getPostResponse != null) {
        // Parse the posts and add in media information which is used elsewhere in the app
        List<PostViewMedia> posts = await parsePostViews([getPostResponse.postView]);

        postView = posts.first;
      }

      GetCommentsResponse getCommentsResponse = await lemmy
          .getComments(
        GetComments(
          page: 1,
          auth: account?.jwt,
          communityId: postView?.post.communityId,
          postId: postView?.post.id,
          sort: CommentSortType.Hot,
          limit: 50,
        ),
      )
          .timeout(timeout, onTimeout: () {
        throw Exception('Error: Timeout when attempting to fetch comments');
      });

      // Build the tree view from the flattened comments
      List<CommentViewTree> commentTree = buildCommentViewTree(getCommentsResponse.comments);

      emit(
        state.copyWith(
          status: PostStatus.success,
          postId: postView?.post.id,
          postView: postView,
          comments: commentTree,
          commentPage: state.commentPage + 1,
          commentCount: getCommentsResponse.comments.length,
          communityId: postView?.post.communityId,
        ),
      );
    } on DioException catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      emit(state.copyWith(status: PostStatus.failure, errorMessage: e.message));
    } catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      emit(state.copyWith(status: PostStatus.failure, errorMessage: e.toString()));
    }
  }

  /// Event to fetch more comments from a post
  Future<void> _getPostCommentsEvent(event, emit) async {
    Account? account = await fetchActiveProfileAccount();
    Lemmy lemmy = LemmyClient.instance.lemmy;

    if (event.reset) {
      emit(state.copyWith(status: PostStatus.loading));

      GetCommentsResponse getCommentsResponse = await lemmy
          .getComments(
        GetComments(
          auth: account?.jwt,
          communityId: state.communityId,
          postId: state.postId,
          sort: CommentSortType.Hot,
          limit: 50,
          page: 1,
        ),
      )
          .timeout(timeout, onTimeout: () {
        throw Exception('Error: Timeout when attempting to fetch comments');
      });

      // Build the tree view from the flattened comments
      List<CommentViewTree> commentTree = buildCommentViewTree(getCommentsResponse.comments);

      return emit(
        state.copyWith(
          status: PostStatus.success,
          comments: commentTree,
          commentPage: 1,
          commentCount: getCommentsResponse.comments.length,
        ),
      );
    }

    // Prevent duplicate requests if we're done fetching comments
    if (state.commentCount >= state.postView!.counts.comments) return;
    emit(state.copyWith(status: PostStatus.refreshing));

    GetCommentsResponse getCommentsResponse = await lemmy
        .getComments(
      GetComments(
        auth: account?.jwt,
        communityId: state.communityId,
        postId: state.postId,
        sort: CommentSortType.Hot,
        limit: 50,
        page: state.commentPage,
      ),
    )
        .timeout(timeout, onTimeout: () {
      throw Exception('Error: Timeout when attempting to fetch more comments');
    });

    // Build the tree view from the flattened comments
    List<CommentViewTree> commentTree = buildCommentViewTree(getCommentsResponse.comments);

    // Append the new comments
    List<CommentViewTree> commentViewTree = List.from(state.comments);
    commentViewTree.addAll(commentTree);

    // We'll add in a edge case here to stop fetching comments after theres no more comments to be fetched
    return emit(state.copyWith(
      status: PostStatus.success,
      comments: commentViewTree,
      commentPage: state.commentPage + 1,
      commentCount: state.commentCount + (getCommentsResponse.comments.isEmpty ? 50 : getCommentsResponse.comments.length),
    ));
  }

  Future<void> _votePostEvent(VotePostEvent event, Emitter<PostState> emit) async {
    try {
      emit(state.copyWith(status: PostStatus.refreshing));

      PostView postView = await votePost(event.postId, event.score).timeout(timeout, onTimeout: () {
        throw Exception('Error: Timeout when attempting to vote post');
      });

      state.postView?.counts = postView.counts;
      state.postView?.post = postView.post;
      state.postView?.myVote = postView.myVote;

      return emit(state.copyWith(status: PostStatus.success));
    } on DioException catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      if (e.type == DioExceptionType.receiveTimeout) return emit(state.copyWith(status: PostStatus.failure, errorMessage: 'Error: Network timeout when attempting to vote'));

      return emit(state.copyWith(status: PostStatus.failure, errorMessage: e.toString()));
    } catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);

      return emit(state.copyWith(status: PostStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _savePostEvent(SavePostEvent event, Emitter<PostState> emit) async {
    try {
      emit(state.copyWith(status: PostStatus.refreshing));

      PostView postView = await savePost(event.postId, event.save).timeout(timeout, onTimeout: () {
        throw Exception('Error: Timeout when attempting to save post');
      });

      state.postView?.counts = postView.counts;
      state.postView?.post = postView.post;
      state.postView?.saved = postView.saved;

      return emit(state.copyWith(status: PostStatus.success));
    } on DioException catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      if (e.type == DioExceptionType.receiveTimeout) return emit(state.copyWith(status: PostStatus.failure, errorMessage: 'Error: Network timeout when attempting to save'));

      return emit(state.copyWith(status: PostStatus.failure, errorMessage: e.toString()));
    } catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);

      emit(state.copyWith(status: PostStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _voteCommentEvent(VoteCommentEvent event, Emitter<PostState> emit) async {
    try {
      emit(state.copyWith(status: PostStatus.refreshing));

      CommentView commentView = await voteComment(event.commentId, event.score).timeout(timeout, onTimeout: () {
        throw Exception('Error: Timeout when attempting to vote on comment');
      });

      List<int> commentIndexes = findCommentIndexesFromCommentViewTree(state.comments, event.commentId);
      CommentViewTree currentTree = state.comments[commentIndexes[0]]; // Get the initial CommentViewTree

      for (int i = 1; i < commentIndexes.length; i++) {
        currentTree = currentTree.replies[commentIndexes[i]]; // Traverse to the next CommentViewTree
      }

      currentTree.myVote = commentView.myVote; // Update the comment's information
      currentTree.counts.score = commentView.counts.score;

      return emit(state.copyWith(status: PostStatus.success));
    } on DioException catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      if (e.type == DioExceptionType.receiveTimeout) return emit(state.copyWith(status: PostStatus.failure, errorMessage: 'Error: Network timeout when attempting to vote on comment'));

      return emit(state.copyWith(status: PostStatus.failure, errorMessage: e.toString()));
    } catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);

      return emit(state.copyWith(status: PostStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _saveCommentEvent(SaveCommentEvent event, Emitter<PostState> emit) async {
    try {
      emit(state.copyWith(status: PostStatus.refreshing));

      CommentView commentView = await saveComment(event.commentId, event.save).timeout(timeout, onTimeout: () {
        throw Exception('Error: Timeout when attempting save a comment');
      });

      List<int> commentIndexes = findCommentIndexesFromCommentViewTree(state.comments, event.commentId);
      CommentViewTree currentTree = state.comments[commentIndexes[0]]; // Get the initial CommentViewTree

      for (int i = 1; i < commentIndexes.length; i++) {
        currentTree = currentTree.replies[commentIndexes[i]]; // Traverse to the next CommentViewTree
      }

      currentTree.saved = commentView.saved; // Update the comment's information

      return emit(state.copyWith(status: PostStatus.success));
    } on DioException catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      if (e.type == DioExceptionType.receiveTimeout) return emit(state.copyWith(status: PostStatus.failure, errorMessage: 'Error: Network timeout when attempting to save'));

      return emit(state.copyWith(status: PostStatus.failure, errorMessage: e.toString()));
    } catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);

      emit(state.copyWith(status: PostStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _createCommentEvent(CreateCommentEvent event, Emitter<PostState> emit) async {
    try {
      emit(state.copyWith(status: PostStatus.refreshing));

      Account? account = await fetchActiveProfileAccount();
      Lemmy lemmy = LemmyClient.instance.lemmy;

      if (account?.jwt == null) {
        return emit(state.copyWith(status: PostStatus.failure, errorMessage: 'You are not logged in. Cannot create a post.'));
      }

      if (state.postView?.post.id == null) {
        return emit(state.copyWith(status: PostStatus.failure, errorMessage: 'Could not determine post to comment to.'));
      }

      CommentResponse createComment = await lemmy.createComment(
        CreateComment(
          auth: account!.jwt!,
          content: event.content,
          postId: state.postView!.post.id,
          parentId: event.parentCommentId,
        ),
      );

      // for now, refresh the post and refetch the comments
      // @todo: insert the new comment in place without requiring a refetch
      add(GetPostEvent(postView: state.postView!));
      return emit(state.copyWith(status: PostStatus.success));
    } on DioException catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);

      if (e.type == DioExceptionType.receiveTimeout) {
        return emit(
          state.copyWith(
            status: PostStatus.failure,
            errorMessage: 'Error: Network timeout when attempting to create a comment',
          ),
        );
      } else {
        return emit(state.copyWith(status: PostStatus.failure, errorMessage: e.toString()));
      }
    } catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      return emit(state.copyWith(status: PostStatus.failure, errorMessage: e.toString()));
    }
  }
}
