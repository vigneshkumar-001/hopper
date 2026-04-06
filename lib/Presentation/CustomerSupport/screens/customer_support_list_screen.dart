import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Presentation/CustomerSupport/controller/customer_support_controller.dart';
import 'package:hopper/Presentation/CustomerSupport/models/customer_support_models.dart';
import 'package:hopper/Presentation/CustomerSupport/screens/create_customer_support_screen.dart';
import 'package:hopper/Presentation/CustomerSupport/screens/customer_support_chat_screen.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';
import 'package:intl/intl.dart';

class CustomerSupportListScreen extends StatefulWidget {
  final String? bookingId;
  const CustomerSupportListScreen({super.key, this.bookingId});

  @override
  State<CustomerSupportListScreen> createState() =>
      _CustomerSupportListScreenState();
}

class _CustomerSupportListScreenState extends State<CustomerSupportListScreen> {
  late final CustomerSupportController c;

  @override
  void initState() {
    super.initState();
    c =
        Get.isRegistered<CustomerSupportController>()
            ? Get.find<CustomerSupportController>()
            : Get.put(CustomerSupportController());
    WidgetsBinding.instance.addPostFrameCallback((_) => c.refreshTickets());
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd.MM.yy');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Support',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Obx(() {
                if (c.isLoading.value && c.tickets.isEmpty) {
                  return const Center(
                    child: HopprCircularLoader(color: Colors.black),
                  );
                }

                if (c.error.value.isNotEmpty && c.tickets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        c.error.value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: Colors.black,
                  onRefresh: c.refreshTickets,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    itemCount: c.tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final t = c.tickets[i];
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) =>
                                      CustomerSupportChatScreen(ticketId: t.id),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE4E7EC)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D000000),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: t.status.accent.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(t.status.icon, color: t.status.accent),
                                    const SizedBox(height: 4),
                                    Text(
                                      t.status.label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: t.status.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.subject,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Created on ${dateFmt.format(t.createdAt)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF98A2B3),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      final res = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder:
                              (_) => CreateCustomerSupportScreen(
                                prefillBookingId: widget.bookingId,
                              ),
                        ),
                      );
                      if (res == true) {
                        await c.refreshTickets();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.commonBlack,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Create Ticket',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
