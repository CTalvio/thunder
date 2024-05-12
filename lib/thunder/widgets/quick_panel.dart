import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:thunder/account/bloc/account_bloc.dart';
import 'package:thunder/core/auth/bloc/auth_bloc.dart';
import 'package:thunder/feed/feed.dart';
import 'package:thunder/thunder/bloc/thunder_bloc.dart';
import '../../community/widgets/community_drawer.dart';

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

class _QuickPanelBody extends State<QuickPanelBody>{
  @override
  void initState() {
    super.initState();

    context.read<AccountBloc>().add(const GetAccountSubscriptions());
    context.read<AccountBloc>().add(const GetFavoritedCommunities());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return makeDismissible(
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller ) => Container(
          color: theme.colorScheme.background,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView(
              controller: controller,
              children: const [
                /*SizedBox(height: 10),*/
                UserDrawerItem(),
                /*PanelFeedItems(),*/
                FavoriteCommunities(),
                /*ModeratedCommunities(),
                SubscribedCommunities(),*/
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget makeDismissible({required Widget child}) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => Navigator.of(context).pop(),
    child: GestureDetector(onTap: () {}, child: child),
  );
}

class QuickVisits extends StatelessWidget {
  const QuickVisits({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Container(
          ),
        ),
      ],
    );
  }
}