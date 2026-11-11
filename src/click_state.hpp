#pragma once

#include <cstdint>

namespace Autoscroll {

    // A quick middle click (short press, no meaningful pointer movement) passes
    // through to the application instead of leaving a scroll session running.
    // This restores middle-click actions such as closing a tab or pasting.
    inline constexpr bool decideClickPassThrough(const bool autoscrollActive, const bool activationButton,
                                                 const bool released, const int64_t elapsedMs,
                                                 const int64_t maxMs, const double displacement,
                                                 const double maxDistance) {
        if (!autoscrollActive || !activationButton || !released)
            return false;

        return maxMs > 0 && elapsedMs <= maxMs && displacement <= maxDistance;
    }

} // namespace Autoscroll
