import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thunder/account/bloc/account_bloc.dart';
import 'package:thunder/community/pages/community_page.dart';
import 'package:thunder/core/auth/bloc/auth_bloc.dart';
import 'package:thunder/core/enums/view_mode.dart';
import 'package:thunder/core/theme/bloc/theme_bloc.dart';
import 'package:thunder/shared/webview.dart';
import 'package:thunder/thunder/bloc/thunder_bloc.dart';
import 'package:thunder/utils/instance.dart';
import 'package:thunder/shared/image_preview.dart';

class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({
    super.key,
    this.originURL,
    this.mediaURL,
    this.mediaHeight,
    this.mediaWidth,
    this.showLinkPreviews = true,
    this.showFullHeightImages = false,
    this.viewMode = ViewMode.comfortable,
  });

  final String? originURL;
  final String? mediaURL;

  final double? mediaHeight;
  final double? mediaWidth;

  final bool showLinkPreviews;
  final bool showFullHeightImages;

  final ViewMode viewMode;

  @override
  Widget build(BuildContext context) {
    if (mediaURL != null && viewMode == ViewMode.comfortable) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(6), // Image border
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6), // Image border
            child: Stack(
              alignment: Alignment.bottomRight,
              fit: StackFit.passthrough,
              children: [
                if (showLinkPreviews)
                  ImagePreview(
                    url: mediaURL!,
                    height: showFullHeightImages ? mediaHeight : null,
                    width: mediaWidth ?? MediaQuery.of(context).size.width - 24,
                    isExpandable: false,
                  ),
                linkInformation(context),
              ],
            ),
          ),
          onTap: () => triggerOnTap(context),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
        child: InkWell(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6), // Image border
            child: Stack(
              alignment: Alignment.bottomRight,
              fit: StackFit.passthrough,
              children: [linkInformation(context)],
            ),
          ),
          onTap: () => triggerOnTap(context),
        ),
      );
    }
  }

  void triggerOnTap(BuildContext context) {
    final openInExternalBrowser = context.read<ThunderBloc>().state.preferences?.getBool('setting_links_open_in_external_browser') ?? false;

    if (originURL != null && originURL!.contains('/c/')) {
      // Push navigation
      AccountBloc accountBloc = context.read<AccountBloc>();
      AuthBloc authBloc = context.read<AuthBloc>();
      ThunderBloc thunderBloc = context.read<ThunderBloc>();

      String? communityName = generateCommunityInstanceUrl(originURL);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: accountBloc),
              BlocProvider.value(value: authBloc),
              BlocProvider.value(value: thunderBloc),
            ],
            child: CommunityPage(communityName: communityName),
          ),
        ),
      );
    } else if (originURL != null) {
      if (openInExternalBrowser) {
        launchUrl(Uri.parse(originURL!), mode: LaunchMode.externalApplication);
      } else {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => WebView(url: originURL!)));
      }
    }
  }

  Widget linkInformation(BuildContext context) {
    final theme = Theme.of(context);
    final useDarkTheme = context.read<ThemeBloc>().state.useDarkTheme;

    if (viewMode == ViewMode.compact) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          color: useDarkTheme ? Colors.grey.shade900 : Colors.grey.shade300,
          child: const SizedBox(
            height: 75.0,
            width: 75.0,
            child: Icon(Icons.link_rounded),
          ),
        ),
      );
    } else {
      return Container(
        color: useDarkTheme ? Colors.grey.shade900 : Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(
                Icons.link,
                color: useDarkTheme ? Colors.white60 : Colors.black54,
              ),
            ),
            if (viewMode != ViewMode.compact)
              Expanded(
                child: Text(
                  originURL!,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      );
    }
  }
}
