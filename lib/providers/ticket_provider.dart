import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ticket_model.dart';
import '../repositories/ticket_repository.dart';

// Provide the TicketRepository instance
final ticketRepositoryProvider = Provider<TicketRepository>((ref) => TicketRepository());

// Stream of stops per route
final routesStreamProvider = StreamProvider<Map<String, List<String>>>((ref) {
  final repository = ref.watch(ticketRepositoryProvider);
  return repository.getRoutesStream();
});

// Stream of global analytics data
final analyticsStreamProvider = StreamProvider<DocumentSnapshot>((ref) {
  final repository = ref.watch(ticketRepositoryProvider);
  return repository.getAnalyticsStream();
});

// UI State class for the Conductor Simulator screen
class TicketUIState {
  final bool isLoading;
  final String? errorMessage;
  final TicketModel? lastGeneratedTicket;
  final bool isSuccess;

  TicketUIState({
    this.isLoading = false,
    this.errorMessage,
    this.lastGeneratedTicket,
    this.isSuccess = false,
  });

  TicketUIState copyWith({
    bool? isLoading,
    String? errorMessage,
    TicketModel? lastGeneratedTicket,
    bool? isSuccess,
  }) {
    return TicketUIState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // Reset if null
      lastGeneratedTicket: lastGeneratedTicket ?? this.lastGeneratedTicket,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// StateNotifier to process tickets and simulation actions
class TicketNotifier extends StateNotifier<TicketUIState> {
  final TicketRepository _repository;

  TicketNotifier(this._repository) : super(TicketUIState());

  // Issue ticket
  Future<void> createTicket({
    required String busNumber,
    required String sourceStop,
    required String destinationStop,
    required int passengerCount,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);
    try {
      final ticket = await _repository.generateTicket(
        busNumber: busNumber,
        sourceStop: sourceStop,
        destinationStop: destinationStop,
        passengerCount: passengerCount,
      );
      state = TicketUIState(
        isLoading: false,
        lastGeneratedTicket: ticket,
        isSuccess: true,
      );
    } catch (e) {
      state = TicketUIState(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Record exits
  Future<void> alightingEvent(String busNumber, int exitCount) async {
    try {
      await _repository.recordPassengerExits(busNumber, exitCount);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to record exits: $e');
    }
  }

  // Pre-load default routes in database
  Future<void> prepopulateRoutes() async {
    try {
      await _repository.initializeDefaultRoutes();
    } catch (_) {}
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

// Provide StateNotifier
final ticketControllerProvider = StateNotifierProvider<TicketNotifier, TicketUIState>((ref) {
  final repository = ref.watch(ticketRepositoryProvider);
  return TicketNotifier(repository);
});
