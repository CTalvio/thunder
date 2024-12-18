import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lemmy_api_client/v3.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:thunder/account/bloc/account_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:thunder/community/widgets/community_drawer.dart';
import 'package:thunder/core/auth/bloc/auth_bloc.dart';
import 'package:thunder/core/enums/full_name.dart';
import 'package:thunder/core/singletons/lemmy_client.dart';
import 'package:thunder/feed/bloc/feed_bloc.dart';
import 'package:thunder/feed/utils/utils.dart';
import 'package:thunder/feed/view/feed_page.dart';
import 'package:thunder/shared/avatars/community_avatar.dart';
import 'package:thunder/utils/instance.dart';
import 'package:thunder/thunder/bloc/thunder_bloc.dart';

import '../../community/bloc/anonymous_subscriptions_bloc.dart';

Future<void> showQuickPanel(
  BuildContext context, {
  String? customHeading,
}) async {
  showModalBottomSheet(
    elevation: 0,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    context: context,
    builder: (context) {
      return const QuickPanelBody();
    },
  );
}

class QuickPanelBody extends StatefulWidget {
  const QuickPanelBody({super.key});

  @override
  State<QuickPanelBody> createState() => _QuickPanelBody();
}

class _QuickPanelBody extends State<QuickPanelBody> {

  bool expandFavorites = false;
  bool expandModerated = false;
  bool expandSubscribed = true;

  @override
  void initState() {
    super.initState();

    context.read<AccountBloc>().add(const GetAccountSubscriptions());
    context.read<AccountBloc>().add(const GetFavoritedCommunities());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    AccountState accountState = context.watch<AccountBloc>().state;

    return BlocProvider(
      create: (context) => FeedBloc(lemmyClient: LemmyClient.instance),
      child: BlocBuilder<FeedBloc, FeedState>(builder: (context, state) {
        return makeDismissible(
          child: DraggableScrollableSheet(
            initialChildSize: 0.4,
            maxChildSize: 1,
            minChildSize: 0.4,
            builder: (_, controller) => Container(
              color: theme.colorScheme.background,
              child: ListView(
                controller: controller,
                children: [
                  UserDrawerItem(),
                  QuickCommunities(),
                  QuickFeedSwitcher(),
                  SizedBox(height: 16),
                  Divider(),
                  InkWell(
                    onTap: () => setState(() => expandFavorites = !expandFavorites),
                    child: ManageFavoriteCommunities(expanded: expandFavorites),
                  ),
                  if (accountState.moderates.isNotEmpty) ...[
                    const Divider(),
                    InkWell(
                      onTap: () =>
                          setState(() => expandModerated = !expandModerated),
                      child: ManageModeratedCommunities(
                          expanded: expandModerated),
                    ),
                  ],
                  Divider(),
                  InkWell(
                    onTap: () => setState(() => expandSubscribed = !expandSubscribed),
                    child: ManageSubscribedCommunities(expanded: expandSubscribed),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget makeDismissible({required Widget child}) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: GestureDetector(onTap: () {}, child: child),
      );
}

class QuickCommunities extends StatelessWidget {
  const QuickCommunities({super.key});

  @override
  Widget build(BuildContext context) {
    FeedState feedState = context.watch<FeedBloc>().state;
    AccountState accountState = context.watch<AccountBloc>().state;
    ThunderState thunderState = context.read<ThunderBloc>().state;
    final theme = Theme.of(context);

    bool isLoggedIn = context.watch<AuthBloc>().state.isLoggedIn;
    if (!isLoggedIn || accountState.favorites.isEmpty) return Container();

    return Column(
      children: [
        const Divider(),
        SizedBox(
          height: 60,
          child: accountState.status != AccountStatus.loading
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: accountState.favorites.length,
                  itemBuilder: (context, index) {
                    Community community = accountState.favorites[index].community;
                    return Align(
                      widthFactor: 0.75,
                      child: SizedBox(
                        width: 60,
                        child: Tooltip(
                          excludeFromSemantics: true,
                          message: '${community.title}\n${generateCommunityFullName(context, community.name, fetchInstanceNameFromUrl(community.actorId))}',
                          preferBelow: false,
                          child: Container(
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), color: theme.colorScheme.background),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(5),
                              ),
                              onPressed: () {
                                /*Navigator.of(context).pop();*/
                                context.read<FeedBloc>().add(
                                      FeedFetchedEvent(
                                        feedType: FeedType.community,
                                        sortType: thunderState.sortTypeForInstance,
                                        communityId: community.id,
                                        reset: true,
                                      ),
                                    );
                              },
                              child: CommunityAvatar(
                                community: community,
                                radius: 30,
                                thumbnailSize: 128,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : const Center(child: SizedBox(height: 28, width: 28, child: CircularProgressIndicator())),
        ),
        const Divider(),
      ],
    );
  }
}

class QuickFeedSwitcher extends StatelessWidget {
  const QuickFeedSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final feedBloc = context.watch<FeedBloc>();

    FeedState feedState = feedBloc.state;
    ThunderState thunderState = context.read<ThunderBloc>().state;

    bool isLoggedIn = context.watch<AuthBloc>().state.isLoggedIn;

    return Column(
      children: destinations.map(
        (Destination destination) {
          return DrawerItem(
            disabled: destination.listingType == ListingType.subscribed && isLoggedIn == false,
            isSelected: destination.listingType == feedState.postListingType,
            onTap: () {
              Navigator.of(context).pop();
              navigateToFeedPage(context, feedType: FeedType.general, postListingType: destination.listingType, sortType: thunderState.sortTypeForInstance);
            },
            label: destination.label,
            icon: destination.icon,
          );
        },
      ).toList(),
    );
  }
}

class ManageFavoriteCommunities extends StatelessWidget {
  final bool expanded;
  const ManageFavoriteCommunities({super.key, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    FeedState feedState = context.watch<FeedBloc>().state;
    AccountState accountState = context.watch<AccountBloc>().state;
    ThunderState thunderState = context.read<ThunderBloc>().state;

    bool isLoggedIn = context.watch<AuthBloc>().state.isLoggedIn;

/*
    if (!isLoggedIn || accountState.favorites.isEmpty) return Container();
*/

    return accountState.status != AccountStatus.loading ? Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [Text(l10n.favorites, style: theme.textTheme.titleMedium), const Spacer(), expanded ? const Icon(Icons.expand_less_rounded) : const Icon(Icons.expand_more_rounded)],
          ),
        ),
        if (accountState.favorites.isNotEmpty) ...[
          AnimatedSwitcher(
            switchOutCurve: Curves.easeInOut,
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
                child: SizeTransition(
                  sizeFactor: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
                  child: child,
                ),
              );
            },
            child: expanded ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: accountState.favorites.length,
                itemBuilder: (context, index) {
                  Community community = accountState.favorites[index].community;
                  bool isCommunitySelected = feedState.communityId == community.id;

                  return TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: isCommunitySelected ? theme.colorScheme.primaryContainer.withOpacity(0.25) : Colors.transparent,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.read<FeedBloc>().add(
                        FeedFetchedEvent(
                          feedType: FeedType.community,
                          sortType: thunderState.sortTypeForInstance,
                          communityId: community.id,
                          reset: true,
                        ),
                      );
                    },
                    child: CommunityItem(community: community, isFavorite: true),
                  );
                },
              ),
            ) : null,
          ),
        ],
        if (accountState.favorites.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8.0),
            child: Text(
              l10n.noFavoritedCommunities,
              style: theme.textTheme.labelLarge?.copyWith(color: theme.dividerColor),
            ),
          )
        ],
      ],
    ) : const SizedBox(height: 55, child: Center(child: SizedBox(height: 28, width: 28, child: CircularProgressIndicator())));
  }
}

class ManageModeratedCommunities extends StatelessWidget {
  final bool expanded;
  const ManageModeratedCommunities({super.key, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    FeedState feedState = context.watch<FeedBloc>().state;
    AccountState accountState = context.watch<AccountBloc>().state;
    ThunderState thunderState = context.read<ThunderBloc>().state;

    List<CommunityModeratorView> moderatedCommunities = accountState.moderates;

    return accountState.status != AccountStatus.loading ? Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (moderatedCommunities.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [Text(l10n.moderatedCommunities, style: theme.textTheme.titleMedium), const Spacer(), expanded ? const Icon(Icons.expand_less_rounded) : const Icon(Icons.expand_more_rounded)],
            ),
          ),
          AnimatedSwitcher(
            switchOutCurve: Curves.easeInOut,
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
                child: SizeTransition(
                  sizeFactor: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
                  child: child,
                ),
              );
            },
            child: expanded ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: moderatedCommunities.length,
                itemBuilder: (context, index) {
                  Community community = moderatedCommunities[index].community;

                  final bool isCommunitySelected = feedState.communityId == community.id;

                  return TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: isCommunitySelected ? theme.colorScheme.primaryContainer.withOpacity(0.25) : Colors.transparent,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.read<FeedBloc>().add(
                        FeedFetchedEvent(
                          feedType: FeedType.community,
                          sortType: thunderState.sortTypeForInstance,
                          communityId: community.id,
                          reset: true,
                        ),
                      );
                    },
                    child: CommunityItem(community: community, showFavoriteAction: false, isFavorite: false),
                  );
                },
              ),
            ) : null,
          ),
        ],
      ],
    ) : const SizedBox(height: 55, child: Center(child: SizedBox(height: 28, width: 28, child: CircularProgressIndicator())));
  }
}

class ManageSubscribedCommunities extends StatelessWidget {
  final bool expanded;
  const ManageSubscribedCommunities({super.key, this.expanded = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    FeedState feedState = context.watch<FeedBloc>().state;
    AccountState accountState = context.watch<AccountBloc>().state;
    ThunderState thunderState = context.read<ThunderBloc>().state;

    AnonymousSubscriptionsBloc subscriptionsBloc = context.watch<AnonymousSubscriptionsBloc>();
    subscriptionsBloc.add(GetSubscribedCommunitiesEvent());

    bool isLoggedIn = context.watch<AuthBloc>().state.isLoggedIn;

    List<Community> subscriptions = [];

    if (isLoggedIn) {
      Set<int> favoriteCommunityIds = accountState.favorites.map((cv) => cv.community.id).toSet();
      Set<int> moderatedCommunityIds = accountState.moderates.map((cmv) => cmv.community.id).toSet();

      List<CommunityView> filteredSubscriptions = accountState.subsciptions
          .where((CommunityView communityView) => !favoriteCommunityIds.contains(communityView.community.id) && !moderatedCommunityIds.contains(communityView.community.id))
          .toList();
      subscriptions = filteredSubscriptions.map((CommunityView communityView) => communityView.community).toList();
    } else {
      subscriptions = subscriptionsBloc.state.subscriptions;
    }

    return accountState.status != AccountStatus.loading ? Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [Text(l10n.subscriptions, style: theme.textTheme.titleMedium), const Spacer(), expanded ? const Icon(Icons.expand_less_rounded) : const Icon(Icons.expand_more_rounded)],
          ),
        ),
        if (subscriptions.isNotEmpty) ...[
          AnimatedSwitcher(
            switchOutCurve: Curves.easeInOut,
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
                child: SizeTransition(
                  sizeFactor: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
                  child: child,
                ),
              );
            },
            child: expanded ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subscriptions.length,
                itemBuilder: (context, index) {
                  Community community = subscriptions[index];

                  final bool isCommunitySelected = feedState.communityId == community.id;

                  return TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: isCommunitySelected ? theme.colorScheme.primaryContainer.withOpacity(0.25) : Colors.transparent,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.read<FeedBloc>().add(
                        FeedFetchedEvent(
                          feedType: FeedType.community,
                          sortType: thunderState.sortTypeForInstance,
                          communityId: community.id,
                          reset: true,
                        ),
                      );
                    },
                    child: CommunityItem(community: community, showFavoriteAction: isLoggedIn, isFavorite: false),
                  );
                },
              ),
            ) : null,
          ),
        ],
        if (subscriptions.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8.0),
            child: Text(
              l10n.noSubscriptions,
              style: theme.textTheme.labelLarge?.copyWith(color: theme.dividerColor),
            ),
          )
        ],
      ],
    ) : const SizedBox(height: 55, child: Center(child: SizedBox(height: 28, width: 28, child: CircularProgressIndicator())));
  }
}