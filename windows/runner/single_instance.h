#ifndef CAVE_PAPER_SINGLE_INSTANCE_H_
#define CAVE_PAPER_SINGLE_INSTANCE_H_
#include <windows.h>
#include <string>
#include <vector>

// Holds a per-user, cross-session mutex until the primary process exits.
// Failure never falls back to opening a second library writer.
class SingleInstance {
 public:
  SingleInstance();
  ~SingleInstance();
  SingleInstance(const SingleInstance&) = delete;
  SingleInstance& operator=(const SingleInstance&) = delete;
  bool primary() const { return primary_; }
  bool Forward(const std::vector<std::wstring>& paths) const;
 private:
  HANDLE mutex_ = nullptr;
  bool primary_ = false;
  std::wstring sid_;
  std::wstring executable_;
};
#endif
