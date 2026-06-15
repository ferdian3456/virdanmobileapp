/// Upload size limits, mirrored from the backend (`internal/constant/constant.go`).
/// Used for client-side pre-validation so an oversized file is rejected before
/// it is uploaded (saving bandwidth); the backend still enforces these.
const int kFreeImageMaxBytes = 10 * 1024 * 1024; // 10 MB
const int kPlusImageMaxBytes = 100 * 1024 * 1024; // 100 MB
const int kFreeVideoMaxBytes = 50 * 1024 * 1024; // 50 MB
const int kPlusVideoMaxBytes = 100 * 1024 * 1024; // 100 MB

int megabytes(int bytes) => bytes ~/ (1024 * 1024);
