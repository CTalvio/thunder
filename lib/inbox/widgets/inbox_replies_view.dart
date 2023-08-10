import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lemmy_api_client/v3.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

import 'package:thunder/account/bloc/account_bloc.dart';
import 'package:thunder/community/pages/community_page.dart';
import 'package:thunder/core/auth/bloc/auth_bloc.dart';

import 'package:thunder/inbox/bloc/inbox_bloc.dart';
import 'package:thunder/post/bloc/post_bloc.dart';
import 'package:thunder/shared/comment_reference.dart';
import 'package:thunder/thunder/bloc/thunder_bloc.dart';
import 'package:thunder/utils/swipe.dart';

import '../../post/widgets/create_comment_modal.dart';

class InboxRepliesView extends StatefulWidget {
  final List<CommentView> replies;

  const InboxRepliesView({super.key, this.replies = const []});

  @override
  State<InboxRepliesView> createState() => _InboxRepliesViewState();
}

class _InboxRepliesViewState extends State<InboxRepliesView> {
  int? inboxReplyMarkedAsRead;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now().toUtc();

    if (widget.replies.isEmpty) {
      return Align(alignment: Alignment.topCenter, heightFactor: (MediaQuery.of(context).size.height / 27), child: const Text('No replies'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.replies.length,
      itemBuilder: (context, index) {
        return Column(
          children: [
            Divider(
              height: 1.0,
              thickness: 1.0,
              color: ElevationOverlay.applySurfaceTint(
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceTint,
                10,
              ),
            ),
            CommentReference(
              comment: widget.replies[index],
              now: now,
              onVoteAction: (int commentId, VoteType voteType) => context.read<PostBloc>().add(VoteCommentEvent(commentId: commentId, score: voteType)),
              onSaveAction: (int commentId, bool save) => context.read<PostBloc>().add(SaveCommentEvent(commentId: commentId, save: save)),
              onDeleteAction: (int commentId, bool deleted) => context.read<PostBloc>().add(DeleteCommentEvent(deleted: deleted, commentId: commentId)),
              onReplyEditAction: (CommentView commentView, bool isEdit) {
                HapticFeedback.mediumImpact();
                InboxBloc inboxBloc = context.read<InboxBloc>();
                PostBloc postBloc = context.read<PostBloc>();
                ThunderBloc thunderBloc = context.read<ThunderBloc>();

                showModalBottomSheet(
                  isScrollControlled: true,
                  context: context,
                  showDragHandle: true,
                  builder: (context) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 40),
                      child: FractionallySizedBox(
                        heightFactor: 0.8,
                        child: MultiBlocProvider(
                          providers: [
                            BlocProvider<InboxBloc>.value(value: inboxBloc),
                            BlocProvider<PostBloc>.value(value: postBloc),
                            BlocProvider<ThunderBloc>.value(value: thunderBloc),
                          ],
                          child: CreateCommentModal(commentView: commentView, isEdit: isEdit),
                        ),
                      ),
                    );
                  },
                );
              },
              isOwnComment: widget.replies[index].creator.id == context.read<AuthBloc>().state.account?.userId,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.replies[index].commentReply?.read == false)
                    inboxReplyMarkedAsRead != widget.replies[index].commentReply?.id
                        ? IconButton(
                            onPressed: () {
                              setState(() => inboxReplyMarkedAsRead = widget.replies[index].commentReply?.id);
                              context.read<InboxBloc>().add(MarkReplyAsReadEvent(commentReplyId: widget.replies[index].commentReply!.id, read: true));
                            },
                            icon: const Icon(
                              Icons.check,
                              semanticLabel: 'Mark as read',
                            ),
                            visualDensity: VisualDensity.compact,
                          )
                        : const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator()),
                          ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void onTapCommunityName(BuildContext context, int communityId) {
    AccountBloc accountBloc = context.read<AccountBloc>();
    AuthBloc authBloc = context.read<AuthBloc>();
    ThunderBloc thunderBloc = context.read<ThunderBloc>();

    Navigator.of(context).push(
      SwipeablePageRoute(
        canOnlySwipeFromEdge: disableFullPageSwipe(isUserLoggedIn: authBloc.state.isLoggedIn, state: thunderBloc.state, isFeedPage: true),
        builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: accountBloc),
            BlocProvider.value(value: authBloc),
            BlocProvider.value(value: thunderBloc),
          ],
          child: CommunityPage(communityId: communityId),
        ),
      ),
    );
  }
}
