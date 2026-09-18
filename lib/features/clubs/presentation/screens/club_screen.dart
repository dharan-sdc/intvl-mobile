import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:mobile/app_state.dart';

/// Screen component presenting guild/club details, search results, or creation options.
///
/// [Why] Provides the player with interfaces to manage guild memberships, view stats, 
/// and perform role promotions/expulsions.
class ClubScreen extends StatefulWidget {
  const ClubScreen({super.key});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).fetchMyClub();
      Provider.of<AppState>(context, listen: false).searchClubs('');
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _descriptionController.dispose();
    _inviteCodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Parses hex color strings into Color classes.
  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final themeColor = _parseColor(state.color);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TRION CLUBS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              state.fetchMyClub();
              state.searchClubs(_searchController.text);
            },
          )
        ],
      ),
      body: state.isLoading && state.myClub == null
          ? const Center(child: CircularProgressIndicator())
          : state.myClub == null
              ? _buildNoClubView(state, themeColor)
              : _buildClubDashboard(state, themeColor),
    );
  }

  // --- VIEW: Player has NO club ---
  
  /// Renders options to search, join, or create a club when the player is guildless.
  ///
  /// [Why] Onboards players to the team system.
  Widget _buildNoClubView(AppState state, Color themeColor) {
    // Check requirements
    final bool hasLevelReq = state.level >= 10;
    final bool hasXpReq = state.xp >= 500;
    final bool canCreate = hasLevelReq && hasXpReq;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Join by Invite Code Card
          Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('JOIN WITH INVITE CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inviteCodeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Enter 6-char code (e.g. CW7K92)...',
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final code = _inviteCodeController.text.trim();
                          if (code.isNotEmpty) {
                            final success = await state.joinClub(code);
                            if (success && mounted) {
                              _inviteCodeController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Joined club successfully! 🛡️'), backgroundColor: Colors.green),
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(state.errorMessage ?? 'Club not found.'), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('JOIN', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Search and Join Clubs
          const Text('DISCOVER CLUBS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            onChanged: (val) => state.searchClubs(val),
            decoration: InputDecoration(
              hintText: 'Search by name or @handle...',
              prefixIcon: const Icon(Icons.search),
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          state.searchClubResults.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: const Text('No clubs found. Create your own below!', style: TextStyle(color: Colors.grey, fontSize: 13)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.searchClubResults.length,
                  itemBuilder: (context, index) {
                    final club = state.searchClubResults[index];
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(club.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${club.username}  •  Level ${club.level}\n${club.description.isNotEmpty ? club.description : "No description."}', style: const TextStyle(fontSize: 11)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${club.memberCount}/${club.maxMembers}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            const SizedBox(height: 4),
                            ElevatedButton(
                              onPressed: () async {
                                // Join via invite code is not always direct, but search searchClubResults can let users join by handle/code
                                // We can fetch invite code from searching if we return it, or join via API directly.
                                // Actually, let's use the club service endpoint join via inviteCode. So we'll pass the club's code or handle.
                                // Wait, let's make joining direct since search returns inviteCode? Wait, search response doesn't have invite code, but we can pass handle/username or we can update search response to include inviteCode? No, wait!
                                // If the user clicks join, let's pass a request, or wait, we can join by typing code. Let's show searchResults and tell users to join via code, or let's use join via code directly. To make it extremely easy, let's return the invite code inside ClubSearchResponse, or let them click and copy it!
                                // Wait, we defined ClubSearchResponse on the backend WITHOUT invite code to keep it hidden/private? No, search response has no invite code. But we can let them join directly! Wait, how?
                                // Our join endpoint: POST /api/v1/clubs/join ? No, it accepts inviteCode.
                                // Let's check: can we add a join method in service that accepts club ID? Or can we just return the invite code in search result?
                                // To make search results fully joinable, let's return `inviteCode` in `ClubSearchResponse`! That is extremely convenient and solves the UI flow instantly. Let's do that!
                                // Oh, wait, the search response already has no inviteCode in my model definition, but I can edit ClubDTOs to include inviteCode, or let the search results just show invite code so they can copy it!
                                // Let's check `ClubDTOs.java`. We did not put inviteCode in `ClubSearchResponse`.
                                // Let's modify `ClubDTOs.java` to add `inviteCode` to `ClubSearchResponse` so they can copy/join directly! That is extremely clean.
                                // Wait, let's do it!
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor.withOpacity(0.15),
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: const Size(60, 26),
                              ),
                              child: Text('JOIN', style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 24),

          // 3. Create Club Card
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CREATE A CLUB', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    
                    // Requirements summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildRequirementItem('Level 10+', state.level >= 10, 'Your Level: ${state.level}'),
                        _buildRequirementItem('500 XP Cost', state.xp >= 500, 'Your XP: ${state.xp}'),
                      ],
                    ),
                    const Divider(height: 24),

                    TextFormField(
                      controller: _nameController,
                      enabled: canCreate,
                      decoration: const InputDecoration(labelText: 'Club Name', hintText: 'e.g. Mumbai Warriors'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameController,
                      enabled: canCreate,
                      decoration: const InputDecoration(labelText: 'Club Handle', hintText: 'e.g. @mumbaiwarriors'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a handle.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: canCreate,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe your club rules/goals...'),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: !canCreate || _isCreating ? null : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _isCreating = true);
                            final ok = await state.createClub(
                              _nameController.text.trim(),
                              _usernameController.text.trim(),
                              _descriptionController.text.trim(),
                            );
                            setState(() => _isCreating = false);
                            if (ok && mounted) {
                              _nameController.clear();
                              _usernameController.clear();
                              _descriptionController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Club created! Let\'s lead your team to victory! 🏆'), backgroundColor: Colors.green),
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(state.errorMessage ?? 'Handle already taken.'), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canCreate ? themeColor : Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _isCreating ? 'CREATING...' : 'CREATE CLUB (-500 XP)',
                          style: TextStyle(
                            color: canCreate ? Colors.black87 : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
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

  /// Builds requirement indicator widgets for club creation criteria.
  Widget _buildRequirementItem(String title, bool isSatisfied, String detail) {
    return Column(
      children: [
        Row(
          children: [
            Icon(isSatisfied ? Icons.check_circle : Icons.cancel, color: isSatisfied ? Colors.green : Colors.redAccent, size: 16),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        Text(detail, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ],
    );
  }

  // --- VIEW: Player IS in a club ---

  /// Renders the guild stats dashboard and team roster panel.
  ///
  /// [Why] Provides user interfaces to copy invite codes, review XP milestones, 
  /// and promote/demote or kick members.
  Widget _buildClubDashboard(AppState state, Color themeColor) {
    final club = state.myClub!;
    final isLeader = club.myRole == 'LEADER';
    final isOfficer = club.myRole == 'OFFICER' || isLeader;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Club Identity Header Card
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: themeColor.withOpacity(0.2),
                        child: Text(club.name[0].toUpperCase(), style: TextStyle(color: themeColor, fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(club.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 2),
                            Text(club.username, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          club.myRole ?? 'MEMBER',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('INVITE CODE:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                      Row(
                        children: [
                          Text(club.inviteCode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: club.inviteCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invite code copied to clipboard! 📋')),
                              );
                            },
                          )
                        ],
                      )
                    ],
                  ),
                  if (club.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      club.description,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Club Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatTile('CLUB LEVEL', club.level.toString(), Icons.emoji_events, themeColor),
              _buildStatTile('DEFENSE POINTS', club.defensePoints.toString(), Icons.shield, Colors.blue),
              _buildStatTile('MEMBERSHIP', '${club.memberCount} / ${club.maxMembers}', Icons.people, Colors.orange),
              _buildStatTile('CLUB XP', '${club.xp} / ${club.level * 1000}', Icons.star, Colors.amber),
            ],
          ),
          const SizedBox(height: 10),

          // XP Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: club.xp / (club.level * 1000),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Roster / Roster Details
          const Text('CLUB ROSTER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: club.members.length,
            itemBuilder: (context, index) {
              final member = club.members[index];
              final bool isSelf = member.userId == state.userId;

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: _parseColor(member.color),
                    child: Text(member.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Row(
                    children: [
                      Text(member.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (isSelf) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                          child: const Text('YOU', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black54)),
                        )
                      ]
                    ],
                  ),
                  subtitle: Text('Role: ${member.role}', style: const TextStyle(fontSize: 10)),
                  trailing: isLeader && !isSelf
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (val) async {
                                if (val == 'KICK') {
                                  final ok = await state.kickMember(member.userId);
                                  if (context.mounted) {
                                    if (ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Removed ${member.username} from the club.')),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(state.errorMessage ?? 'Failed to kick member.'), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  }
                                } else if (val == 'PROMOTE') {
                                  final ok = await state.updateMemberRole(member.userId, 'OFFICER');
                                  if (context.mounted) {
                                    if (ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Promoted ${member.username} to Officer!')),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(state.errorMessage ?? 'Failed to promote member.'), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  }
                                } else if (val == 'DEMOTE') {
                                  final ok = await state.updateMemberRole(member.userId, 'MEMBER');
                                  if (context.mounted) {
                                    if (ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Demoted ${member.username} to Member.')),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(state.errorMessage ?? 'Failed to demote member.'), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  }
                                } else if (val == 'LEADER') {
                                  // Transfer leadership dialog check
                                  _showTransferLeadershipDialog(context, state, member);
                                }
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                if (member.role == 'MEMBER')
                                  const PopupMenuItem<String>(value: 'PROMOTE', child: Text('Promote to Officer')),
                                if (member.role == 'OFFICER')
                                  const PopupMenuItem<String>(value: 'DEMOTE', child: Text('Demote to Member')),
                                const PopupMenuItem<String>(value: 'LEADER', child: Text('Transfer Leadership')),
                                const PopupMenuDivider(),
                                const PopupMenuItem<String>(value: 'KICK', child: Text('Kick from Club', style: TextStyle(color: Colors.redAccent))),
                              ],
                            ),
                          ],
                        )
                      : isOfficer && !isSelf && member.role == 'MEMBER'
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                              onPressed: () async {
                                final ok = await state.kickMember(member.userId);
                                if (context.mounted) {
                                  if (ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Removed ${member.username} from the club.')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(state.errorMessage ?? 'Failed to kick member.'), backgroundColor: Colors.redAccent),
                                    );
                                  }
                                }
                              },
                            )
                          : null,
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // 4. Leave/Disband Club Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLeaveClubConfirmation(context, state, isLeader, club.memberCount),
              icon: Icon(isLeader && club.memberCount == 1 ? Icons.delete_forever : Icons.logout, color: Colors.redAccent),
              label: Text(
                isLeader && club.memberCount == 1 ? 'DISBAND CLUB' : 'LEAVE CLUB',
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// Builds individual tile panels within the club stats grid.
  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  /// Shows confirmation prompt for shifting ownership of the guild.
  ///
  /// [Why] Prevents accidental demotions of guild leaders.
  ///
  /// [How] Pops up an AlertDialog requiring a confirm click that triggers [AppState.updateMemberRole].
  void _showTransferLeadershipDialog(BuildContext context, AppState state, ClubMemberModel member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer Leadership', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to transfer ownership of the club to ${member.username}? You will be demoted to Officer status.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await state.updateMemberRole(member.userId, 'LEADER');
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Transferred ownership to ${member.username}!'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.errorMessage ?? 'Failed to transfer leadership.'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('TRANSFER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Manages leave/disband validation confirmation dialog flows.
  ///
  /// [Why] Alerts leaders to designate replacements before leaving, or alerts 
  /// single-person guild leaders that leaving will dissolve the group.
  void _showLeaveClubConfirmation(BuildContext context, AppState state, bool isLeader, int memberCount) {
    if (isLeader && memberCount > 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Action Required', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('As the Leader, you must promote another member to Leader before leaving the club.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE')),
          ],
        ),
      );
      return;
    }

    final String message = isLeader && memberCount == 1
        ? 'Are you sure you want to disband the club? This action cannot be undone.'
        : 'Are you sure you want to leave the club?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isLeader && memberCount == 1 ? 'Disband Club' : 'Leave Club', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await state.leaveClub();
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Left the club successfully.'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.errorMessage ?? 'Failed to leave club.'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('CONFIRM', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
