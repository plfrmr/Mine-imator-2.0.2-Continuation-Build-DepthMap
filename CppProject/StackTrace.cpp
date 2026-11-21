// Call stack for fatal error logs: return addresses as offsets into the executable, which can be looked up in the linker's
// Mine-imator.map (or with the .pdb in debug builds).
#include <QString>

#ifdef _WIN32
#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

namespace CppProject
{
	QString StackTraceOffsets()
	{
	#ifdef _WIN32
		void* frames[48];
		USHORT count = RtlCaptureStackBackTrace(2, 48, frames, nullptr);
		uintptr_t base = (uintptr_t)GetModuleHandleW(nullptr);
		QString stack = "Stack (offsets in the executable):";
		for (USHORT i = 0; i < count; i++)
			stack += " " + QString::number((qulonglong)((uintptr_t)frames[i] - base), 16);
		return stack;
	#else
		return "";
	#endif
	}
}
