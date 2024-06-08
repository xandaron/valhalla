#include "instance.h"

vk::Instance vkInit::makeInstance(std::string applicationName) {
	uint32_t version = vk::enumerateInstanceVersion();
	std::string message = std::format(
		"System can support vulkan Variant: {}, Major: {}, Minor: {}, Patch: {}",
		VK_API_VERSION_VARIANT(version),
		VK_API_VERSION_MAJOR(version),
		VK_API_VERSION_MINOR(version),
		VK_API_VERSION_PATCH(version)
	);
	Debug::Logger::log(Debug::DEBUG, message);
	/**
	* We can then either use this version or drop down to an
	* earlier version to ensure compatibility with more devices
	* VK_MAKE_API_VERSION(variant, major, minor, patch)
	* 
	* VULKAN_HPP_CONSTEXPR ApplicationInfo(
	*	const char * pApplicationName_   = {},
	*	uint32_t     applicationVersion_ = {},
	*	const char * pEngineName_        = {},
	*	uint32_t     engineVersion_      = {},
	*	uint32_t     apiVersion_         = {})
	*/
	vk::ApplicationInfo appInfo = {
		applicationName.c_str(),
		version,
		"Celest Graphics Engine",
		version,
		version
	};

	uint32_t glfwExtensionCount = 0;
	const char** glfwExtensions;
	glfwExtensions = glfwGetRequiredInstanceExtensions(&glfwExtensionCount);
	std::vector<const char*> extensions(glfwExtensions, glfwExtensions + glfwExtensionCount);
	extensions.push_back("VK_EXT_debug_utils");

	Debug::Logger::log(Debug::DEBUG, "Required extensions:");
	for (const char* extensionName : extensions) {
		Debug::Logger::log(Debug::DEBUG, std::format("\t\"{}\"", extensionName));
	}
	std::vector<const char*> layers{ "VK_LAYER_KHRONOS_validation" };
	checkSupport(extensions, layers);
	/**
	* InstanceCreateInfo(
	*	VULKAN_HPP_NAMESPACE::InstanceCreateFlags     flags_                   = {},
	*	const VULKAN_HPP_NAMESPACE::ApplicationInfo * pApplicationInfo_        = {},
	*	uint32_t                                      enabledLayerCount_       = {},
	*	const char * const *                          ppEnabledLayerNames_     = {},
	*	uint32_t                                      enabledExtensionCount_   = {},
	*	const char * const *						  ppEnabledExtensionNames_ = {})
	*/
	vk::InstanceCreateInfo createInfo = {
		vk::InstanceCreateFlags(),
		&appInfo,
		static_cast<uint32_t>(layers.size()),
		layers.data(),
		static_cast<uint32_t>(extensions.size()),
		extensions.data()
	};

	try {
		/**
		* createInstance(
		*	const VULKAN_HPP_NAMESPACE::InstanceCreateInfo &          createInfo,
		*	Optional<const VULKAN_HPP_NAMESPACE::AllocationCallbacks> allocator  = nullptr,
		*	Dispatch const &                                          d			 = ::vk::getDispatchLoaderStatic())

		*/
		return vk::createInstance(createInfo);
	}
	catch (vk::SystemError err) {
		throw std::runtime_error(std::format("Vulkan failed to create instance. Reason:\n\t{}", err.what()).c_str());
	}
}

void vkInit::checkSupport(std::vector<const char*>& extensions, std::vector<const char*>& layers) {
	std::vector<vk::ExtensionProperties> supportedExtensions = vk::enumerateInstanceExtensionProperties();
	bool found;
	for (const char* extension : extensions) {
		found = false;
		for (vk::ExtensionProperties supportedExtension : supportedExtensions) {
			if (strcmp(extension, supportedExtension.extensionName) == 0) {
				found = true;
				Debug::Logger::log(Debug::MESSAGE, std::format("Extension \"{}\" is supported!", extension));
			}
		}
		if (!found) {
			throw std::runtime_error(std::format("Required format \"{}\" is not supported by the system.", extension).c_str());
		}
	}

	std::vector<vk::LayerProperties> supportedLayers = vk::enumerateInstanceLayerProperties();
	for (const char* layer : layers) {
		found = false;
		for (vk::LayerProperties supportedLayer : supportedLayers) {
			if (strcmp(layer, supportedLayer.layerName) == 0) {
				found = true;
				Debug::Logger::log(Debug::MESSAGE, std::format("Layer \"{}\" is supported!", layer));
			}
		}
		if (!found) {
			throw std::runtime_error(std::format("Required layer \"{}\" is not supported by the system.", layer).c_str());
		}
	}
}