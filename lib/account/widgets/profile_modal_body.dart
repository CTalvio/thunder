import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

import 'package:thunder/account/models/account.dart';
import 'package:thunder/account/pages/login_page.dart';
import 'package:thunder/core/auth/bloc/auth_bloc.dart';
import 'package:thunder/utils/instance.dart';

class ProfileModalBody extends StatelessWidget {
  const ProfileModalBody({super.key});

  static final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

  void pushRegister() {
    shellNavigatorKey.currentState!.pushNamed("/login");
  }

  void popRegister() {
    shellNavigatorKey.currentState!.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: shellNavigatorKey,
      onPopPage: (route, result) => false,
      pages: [MaterialPage(child: ProfileSelect(pushRegister: pushRegister))],
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route _onGenerateRoute(RouteSettings settings) {
    late Widget page;
    switch (settings.name) {
      case '/':
        page = ProfileSelect(pushRegister: pushRegister);
        break;

      case '/login':
        page = LoginPage(popRegister: popRegister);
        break;
    }
    return SwipeablePageRoute<dynamic>(
      builder: (context) {
        return page;
      },
      settings: settings,
    );
  }
}

class ProfileSelect extends StatefulWidget {
  final VoidCallback pushRegister;
  const ProfileSelect({Key? key, required this.pushRegister}) : super(key: key);

  @override
  State<ProfileSelect> createState() => _ProfileSelectState();
}

class _ProfileSelectState extends State<ProfileSelect> {
  List<AccountExtended>? accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String? currentAccountId = context.read<AuthBloc>().state.account?.id;

    if (accounts == null) {
      fetchAccounts();
    }

    if (accounts != null) {
      return ListView.builder(
        itemBuilder: (context, index) {
          if (index == accounts?.length) {
            return Column(
              children: [
                if (accounts != null && accounts!.isNotEmpty) const Divider(indent: 16.0, endIndent: 16.0, thickness: 2.0),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add Account'),
                  onTap: () => widget.pushRegister(),
                ),
              ],
            );
          } else {
            return ListTile(
              leading: Stack(
                children: [
                  AnimatedCrossFade(
                    crossFadeState: accounts![index].instanceIcon == null ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 500),
                    firstChild: const SizedBox(
                      child: Padding(
                        padding: EdgeInsets.only(left: 8, top: 8, right: 8, bottom: 8),
                        child: Icon(
                          Icons.person,
                        ),
                      ),
                    ),
                    secondChild: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      foregroundImage: accounts![index].instanceIcon == null ? null : CachedNetworkImageProvider(accounts![index].instanceIcon!),
                      maxRadius: 20,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      opacity: accounts![index].alive == null ? 0 : 1,
                      duration: const Duration(milliseconds: 500),
                      child: Icon(
                        accounts![index].alive == true ? Icons.check_circle_rounded : Icons.remove_circle_rounded,
                        size: 10,
                        color: Color.alphaBlend(theme.colorScheme.primaryContainer.withOpacity(0.6), accounts![index].alive == true ? Colors.green : Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                accounts![index].account.username ?? 'N/A',
                style: theme.textTheme.titleMedium?.copyWith(),
              ),
              subtitle: Row(
                children: [
                  Text(accounts![index].account.instance?.replaceAll('https://', '') ?? 'N/A'),
                  AnimatedOpacity(
                    opacity: accounts![index].latency == null ? 0 : 1,
                    duration: const Duration(milliseconds: 500),
                    child: Row(
                      children: [
                        const SizedBox(width: 5),
                        Text(
                          '•',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.55),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${accounts![index].latency?.inMilliseconds}ms',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: (currentAccountId == accounts![index].account.id)
                  ? null
                  : () {
                      context.read<AuthBloc>().add(SwitchAccount(accountId: accounts![index].account.id));
                      context.pop();
                    },
              trailing: (currentAccountId == accounts![index].account.id)
                  ? const InputChip(
                      label: Text('Active'),
                      visualDensity: VisualDensity.compact,
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.delete,
                        semanticLabel: 'Remove Account',
                      ),
                      onPressed: () {
                        context.read<AuthBloc>().add(RemoveAccount(accountId: accounts![index].account.id));
                        context.pop();
                      }),
            );
          }
        },
        itemCount: (accounts?.length ?? 0) + 1,
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Future<void> fetchAccounts() async {
    List<Account> accounts = await Account.accounts();

    List<AccountExtended> accountsExtended = await Future.wait(accounts.map((Account account) async {
      return AccountExtended(account: account, instance: account.instance, instanceIcon: null);
    })).timeout(const Duration(seconds: 5));

    // Intentionally don't await these here
    fetchInstanceIcons(accountsExtended);
    pingInstances(accountsExtended);

    setState(() => this.accounts = accountsExtended);
  }

  Future<void> fetchInstanceIcons(List<AccountExtended> accountsExtended) async {
    accountsExtended.forEach((account) async {
      final GetInstanceIconResponse instanceIconResponse = await getInstanceIcon(account.instance).timeout(
        const Duration(seconds: 3),
        onTimeout: () => const GetInstanceIconResponse(success: false),
      );

      setState(() {
        account.instanceIcon = instanceIconResponse.icon;
        account.alive = instanceIconResponse.success;
      });
    });
  }

  Future<void> pingInstances(List<AccountExtended> accountsExtended) async {
    accountsExtended.forEach((account) async {
      if (account.instance != null) {
        PingData pingData = await Ping(
          account.instance!,
          count: 1,
          timeout: 5,
        ).stream.first;
        setState(() => account.latency = pingData.response?.time);
      }
    });
  }
}

/// Wrapper class around Account with support for instance icon
class AccountExtended {
  final Account account;
  String? instance;
  String? instanceIcon;
  Duration? latency;
  bool? alive;

  AccountExtended({required this.account, this.instance, this.instanceIcon});
}
