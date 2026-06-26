import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/navigation_item.dart';
import 'package:eflutter/presentation/app/widgets/main_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class WebLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  WebLayout({super.key, required this.navigationShell});

  final itemGroups = NavigationItem.itemGroups;
  final allItems = NavigationItem.allItems;

  void _onTabTapped(NavigationItem item) {
    final index = allItems.indexOf(item);
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isMobile = maxWidth < 640;
        final isDesktop = maxWidth >= 960;
        return Scaffold(
          appBar: MainAppBar(onNotificationPressed: () {}),
          drawer: isMobile
              ? _MobileDrawer(
                  itemGroups: itemGroups,
                  selectedItem: allItems[navigationShell.currentIndex],
                  onTabTapped: _onTabTapped,
                )
              : null,
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMobile) ...[
                  _NavigationSideBar(
                    isDesktop: isDesktop,
                    itemGroups: itemGroups,
                    selectedItem: allItems[navigationShell.currentIndex],
                    onTabTapped: _onTabTapped,
                  ),

                  const VerticalDivider(width: 1, thickness: 1),
                ],
                Expanded(child: navigationShell),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({
    required this.itemGroups,
    required this.selectedItem,
    required this.onTabTapped,
  });

  final Map<NavigationItemGroup, List<NavigationItem>> itemGroups;
  final NavigationItem selectedItem;
  final Function(NavigationItem item) onTabTapped;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: _NavigationSideBar(
        isMobile: true,
        itemGroups: itemGroups,
        selectedItem: selectedItem,
        onTabTapped: (item) {
          onTabTapped(item);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _NavigationSideBar extends StatefulWidget {
  const _NavigationSideBar({
    this.isMobile = false,
    this.isDesktop = false,
    required this.itemGroups,
    required this.selectedItem,
    required this.onTabTapped,
  });

  final bool isMobile;
  final bool isDesktop;
  final Map<NavigationItemGroup, List<NavigationItem>> itemGroups;
  final NavigationItem selectedItem;
  final Function(NavigationItem item) onTabTapped;

  @override
  State<_NavigationSideBar> createState() => _NavigationSideBarState();
}

class _NavigationSideBarState extends State<_NavigationSideBar> {
  late bool isExpanded;

  final double expandedWidth = 224;
  final double collapsedWidth = 80;

  @override
  void initState() {
    super.initState();
    isExpanded = widget.isDesktop || widget.isMobile;
  }

  @override
  void didUpdateWidget(covariant _NavigationSideBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDesktop != widget.isDesktop ||
        oldWidget.isMobile != widget.isMobile) {
      isExpanded = widget.isDesktop || widget.isMobile;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isExpanded ? expandedWidth : collapsedWidth,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    if (!widget.isMobile)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ColorName.gray5),
                        ),
                        child: InkWell(
                          onTap: () => setState(() => isExpanded = !isExpanded),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isExpanded) ...[
                                  const Expanded(
                                    child: Text(
                                      'Collapse',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: ColorName.labelSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                Icon(
                                  isExpanded
                                      ? SolarIconsOutline.sendSquare
                                      : SolarIconsOutline.receiveSquare,
                                  color: ColorName.labelSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    for (final group in widget.itemGroups.keys)
                      _NavigationSideBarGroup(
                        isExpanded: isExpanded,
                        group: group,
                        items: widget.itemGroups[group]!,
                        selectedItem: widget.selectedItem,
                        onTabTapped: widget.onTabTapped,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationSideBarGroup extends StatefulWidget {
  const _NavigationSideBarGroup({
    required this.isExpanded,
    required this.group,
    required this.items,
    required this.selectedItem,
    required this.onTabTapped,
  });

  final bool isExpanded;
  final NavigationItemGroup group;
  final List<NavigationItem> items;
  final NavigationItem selectedItem;
  final Function(NavigationItem item) onTabTapped;

  @override
  State<_NavigationSideBarGroup> createState() =>
      _NavigationSideBarGroupState();
}

class _NavigationSideBarGroupState extends State<_NavigationSideBarGroup> {
  bool isGroupExpanded = true;

  void toggleGroupExpanded() {
    setState(() {
      isGroupExpanded = !isGroupExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 4,
      crossAxisAlignment: widget.isExpanded
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        widget.isExpanded
            ? InkWell(
                onTap: toggleGroupExpanded,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.group.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ColorName.labelSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        isGroupExpanded
                            ? SolarIconsOutline.altArrowDown
                            : SolarIconsOutline.altArrowRight,
                        color: ColorName.labelSecondary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              )
            : const Center(
                child: SizedBox(width: 60, child: Divider(height: 1)),
              ),
        Builder(
          builder: (context) {
            final itemsList = Column(
              spacing: 4,
              crossAxisAlignment: widget.isExpanded
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                for (final item in widget.items)
                  Builder(
                    builder: (context) {
                      final isSelected = widget.selectedItem == item;
                      return InkWell(
                        onTap: () => widget.onTabTapped(item),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ColorName.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Flex(
                            spacing: 8,
                            direction: widget.isExpanded
                                ? Axis.horizontal
                                : Axis.vertical,
                            children: [
                              Icon(
                                isSelected ? item.selectedIcon : item.icon,
                                color: isSelected
                                    ? ColorName.primary
                                    : ColorName.labelPrimary,
                                size: 20,
                              ),
                              widget.isExpanded
                                  ? Expanded(
                                      child: Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? ColorName.primary
                                              : ColorName.labelPrimary,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      item.shortTitle ?? item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? ColorName.primary
                                            : ColorName.labelPrimary,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );

            if (widget.isExpanded) {
              return AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: itemsList,
                crossFadeState: isGroupExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
                sizeCurve: Curves.easeInOut,
              );
            } else {
              return itemsList;
            }
          },
        ),
      ],
    );
  }
}
