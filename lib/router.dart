import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/bible/book_list_screen.dart';
import 'features/bible/chapter_list_screen.dart';
import 'features/bible/reader_screen.dart';
import 'features/library/library_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/tour/tour_screen.dart';
import 'features/wonders/wonder_detail_screen.dart';
import 'features/wonders/wonders_home_screen.dart';

/// The four tabs, and one navigator stack each.
///
/// StatefulShellRoute is the whole reason this app can be split into a Bible
/// screen and a Wonders screen without breaking what makes it worth using.
/// A wonder's passage opens *inside the Wonders branch* — same reader, same
/// tab — so following a card into Exodus 14 never costs you your place in the
/// catalog, and the Bible tab keeps whatever chapter you left it on.
///
/// The corollary: nothing here should ever `go('/bible/...')` in order to show
/// a wonder's passage. That is a tab switch, and it throws away both stacks.
class AppRouter {
  const AppRouter._();

  static GoRouter build() {
    return GoRouter(
      initialLocation: '/wonders',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => HomeShell(shell: shell),
          branches: [
            /* --- Wonders ------------------------------------------------- */
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/wonders',
                  builder: (context, state) => const WondersHomeScreen(),
                  routes: [
                    GoRoute(
                      path: ':wonderId',
                      builder: (context, state) => WonderDetailScreen(
                        wonderId: state.pathParameters['wonderId']!,
                        // Deep links can land straight on the passage page;
                        // in-app navigation always starts on the card.
                        initialPage:
                            state.uri.queryParameters['page'] == 'passage'
                                ? WonderDetailPage.passage
                                : WonderDetailPage.card,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            /* --- Bible --------------------------------------------------- */
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/bible',
                  builder: (context, state) => const BookListScreen(),
                  routes: [
                    GoRoute(
                      path: ':bookId',
                      builder: (context, state) => ChapterListScreen(
                        bookId: state.pathParameters['bookId']!,
                      ),
                      routes: [
                        GoRoute(
                          path: ':chapterNumber',
                          builder: (context, state) => ReaderScreen(
                            chapterId: '${state.pathParameters['bookId']}'
                                '.${state.pathParameters['chapterNumber']}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            /* --- Tour ---------------------------------------------------- */
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tour',
                  builder: (context, state) => const TourScreen(),
                ),
              ],
            ),

            /* --- More ---------------------------------------------------- */
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/more',
                  builder: (context, state) => const SettingsScreen(),
                  routes: [
                    GoRoute(
                      path: 'library',
                      builder: (context, state) => const LibraryScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'That page does not exist.\n\n${state.uri}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
