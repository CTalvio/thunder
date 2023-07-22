import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lemmy_api_client/v3.dart';
import 'package:thunder/community/utils/post_card_action_helpers.dart';

import 'package:thunder/core/enums/font_scale.dart';
import 'package:thunder/shared/community_icon.dart';
import 'package:thunder/shared/icon_text.dart';
import 'package:thunder/thunder/bloc/thunder_bloc.dart';
import 'package:thunder/utils/date_time.dart';
import 'package:thunder/utils/instance.dart';
import 'package:thunder/utils/numbers.dart';

class PostCardMetaData extends StatelessWidget {
  final int score;
  final VoteType voteType;
  final int unreadComments;
  final int comments;
  final bool hasBeenEdited;
  final DateTime published;
  final bool saved;
  final bool distinguised;

  const PostCardMetaData({
    super.key,
    required this.score,
    required this.voteType,
    required this.unreadComments,
    required this.comments,
    required this.hasBeenEdited,
    required this.published,
    required this.saved,
    required this.distinguised,
  });

  final MaterialColor upVoteColor = Colors.orange;
  final MaterialColor downVoteColor = Colors.blue;
  final MaterialColor savedColor = Colors.purple;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<ThunderBloc, ThunderState>(
      builder: (context, state) {
        final bool useCompactView = state.useCompactView;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconText(
                  textScaleFactor: state.contentFontSizeScale.textScaleFactor,
                  text: formatNumberToK(score),
                  textColor: voteType == VoteType.up
                      ? upVoteColor
                      : voteType == VoteType.down
                          ? downVoteColor
                          : theme.textTheme.titleSmall?.color?.withOpacity(0.9),
                  icon: Icon(voteType == VoteType.up ? Icons.arrow_upward : (voteType == VoteType.down ? Icons.arrow_downward : (score < 0 ? Icons.arrow_downward : Icons.arrow_upward)),
                      size: 18.0,
                      color: voteType == VoteType.up
                          ? upVoteColor
                          : voteType == VoteType.down
                              ? downVoteColor
                              : theme.textTheme.titleSmall?.color?.withOpacity(0.75)),
                  padding: 2.0,
                ),
                const SizedBox(width: 12.0),
                IconText(
                  textScaleFactor: state.contentFontSizeScale.textScaleFactor,
                  icon: Icon(
                    /*unreadComments != 0 && unreadComments != comments ? Icons.mark_unread_chat_alt_rounded  :*/ Icons
                        .chat,
                    size: 17.0,
                    color: /*unreadComments != 0 && unreadComments != comments ? theme.primaryColor :*/
                        theme.textTheme.titleSmall?.color?.withOpacity(0.75),
                  ),
                  text: /*unreadComments != 0 && unreadComments != comments ? '+${formatNumberToK(unreadComments)}' :*/
                      formatNumberToK(comments),
                  textColor: /*unreadComments != 0 && unreadComments != comments ? theme.primaryColor :*/
                      theme.textTheme.titleSmall?.color?.withOpacity(0.9),
                  padding: 5.0,
                ),
                const SizedBox(width: 10.0),
                IconText(
                  textScaleFactor: state.contentFontSizeScale.textScaleFactor,
                  icon: Icon(
                    hasBeenEdited
                        ? Icons.refresh_rounded
                        : Icons.history_rounded,
                    size: 19.0,
                    color: theme.textTheme.titleSmall?.color?.withOpacity(0.75),
                  ),
                  text:
                      formatTimeToString(dateTime: published.toIso8601String()),
                  textColor:
                      theme.textTheme.titleSmall?.color?.withOpacity(0.9),
                ),
                const SizedBox(width: 14.0),
                if (distinguised)
                  Icon(
                    Icons.campaign_rounded,
                    size: 24.0,
                    color: Colors.green.shade800,
                  ),
              ],
            ),
            if (useCompactView)
              Icon(
                saved ? Icons.star_rounded : null,
                color: saved ? savedColor : null,
                size: 22.0,
                semanticLabel: saved ? 'Saved' : '',
              ),
          ],
        );
      },
    );
  }
}

class PostViewMetaData extends StatelessWidget {
  final int unreadComments;
  final int comments;
  final bool hasBeenEdited;
  final DateTime published;
  final bool saved;

  const PostViewMetaData({
    super.key,
    required this.unreadComments,
    required this.comments,
    required this.hasBeenEdited,
    required this.published,
    required this.saved,
  });

  final MaterialColor upVoteColor = Colors.orange;
  final MaterialColor downVoteColor = Colors.blue;
  final MaterialColor savedColor = Colors.purple;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<ThunderBloc, ThunderState>(
      builder: (context, state) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                /*Container(
                  child: unreadComments != 0 && unreadComments != comments ? Row(
                    children: [
                      IconText(
                        textScaleFactor: state.contentFontSizeScale.textScaleFactor,
                        icon: Icon(
                          Icons.mark_unread_chat_alt_rounded,
                          size: 17.0,
                          color: theme.primaryColor,
                        ),
                        text: '+${formatNumberToK(unreadComments)}',
                        textColor: theme.primaryColor,
                        padding: 5.0,
                      ),
                      const SizedBox(width: 10.0),
                    ],
                  ) : null,
                ),*/
                IconText(
                  textScaleFactor: state.contentFontSizeScale.textScaleFactor,
                  icon: Icon(
                    Icons.chat,
                    size: 17.0,
                    color: theme.textTheme.titleSmall?.color?.withOpacity(0.75),
                  ),
                  text: formatNumberToK(comments),
                  textColor:
                      theme.textTheme.titleSmall?.color?.withOpacity(0.9),
                  padding: 5.0,
                ),
                const SizedBox(width: 10.0),
                IconText(
                  textScaleFactor: state.contentFontSizeScale.textScaleFactor,
                  icon: Icon(
                    hasBeenEdited
                        ? Icons.refresh_rounded
                        : Icons.history_rounded,
                    size: 19.0,
                    color: theme.textTheme.titleSmall?.color?.withOpacity(0.75),
                  ),
                  text:
                      formatTimeToString(dateTime: published.toIso8601String()),
                  textColor:
                      theme.textTheme.titleSmall?.color?.withOpacity(0.9),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class PostCommunityAndAuthor extends StatelessWidget {
  const PostCommunityAndAuthor({
    super.key,
    required this.showCommunityIcons,
    required this.postView,
    required this.showInstanceName,
    this.textStyleAuthor,
    this.textStyleCommunity,
  });

  final bool showCommunityIcons;
  final PostView postView;
  final bool showInstanceName;
  final TextStyle? textStyleAuthor;
  final TextStyle? textStyleCommunity;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThunderBloc, ThunderState>(builder: (context, state) {
      return Row(
        children: [
          if (showCommunityIcons)
            GestureDetector(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CommunityIcon(community: postView.community, radius: 14),
              ),
              onTap: () => onTapCommunityName(context, postView.community.id),
            ),
          Expanded(
            child: Wrap(
              direction: Axis.horizontal,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 1.0,
              children: [
                GestureDetector(
                    child: Text('${postView.creator.name} to ',
                        textScaleFactor:
                            state.contentFontSizeScale.textScaleFactor,
                        style: textStyleAuthor),
                    onTap: () => onTapUserName(context, postView.creator.id)),
                GestureDetector(
                    child: Text(
                      '${postView.community.name}${showInstanceName ? ' · ${fetchInstanceNameFromUrl(postView.community.actorId)}' : ''}',
                      textScaleFactor:
                          state.contentFontSizeScale.textScaleFactor,
                      style: textStyleCommunity,
                    ),
                    onTap: () =>
                        onTapCommunityName(context, postView.community.id)),
              ],
            ),
          ),
        ],
      );
    });
  }
}
