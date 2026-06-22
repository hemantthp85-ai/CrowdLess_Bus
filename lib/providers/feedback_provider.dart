import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feedback_model.dart';
import '../repositories/ticket_repository.dart';
import 'ticket_provider.dart';

// Provide feedback stream for a specific bus
final feedbackStreamProvider = StreamProvider.family<List<FeedbackModel>, String>((ref, busNumber) {
  final ticketRepo = ref.watch(ticketRepositoryProvider);
  return ticketRepo.getFeedbackStream(busNumber);
});

// UI state for feedback submission
class FeedbackUIState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  FeedbackUIState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  FeedbackUIState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return FeedbackUIState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class FeedbackNotifier extends StateNotifier<FeedbackUIState> {
  final TicketRepository _repository;

  FeedbackNotifier(this._repository) : super(FeedbackUIState());

  Future<void> submitFeedback({
    required String busNumber,
    required String crowdLevel,
    required String userId,
  }) async {
    state = FeedbackUIState(isLoading: true);
    try {
      await _repository.submitFeedback(
        busNumber: busNumber,
        crowdLevel: crowdLevel,
        userId: userId,
      );
      state = FeedbackUIState(isSuccess: true);
    } catch (e) {
      state = FeedbackUIState(errorMessage: e.toString());
    }
  }

  void clearState() {
    state = FeedbackUIState();
  }
}

final feedbackControllerProvider = StateNotifierProvider<FeedbackNotifier, FeedbackUIState>((ref) {
  final repository = ref.watch(ticketRepositoryProvider);
  return FeedbackNotifier(repository);
});
