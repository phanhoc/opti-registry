// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @title DNSEncoder
/// @notice Library for DNS name encoding and validation following RFC 1035 standards
/// @dev Implements DNS wire format encoding with length-prefixed labels
library DNSEncoder {
    uint8 constant MAX_LABEL_LENGTH = 63;
    uint8 constant MAX_NAME_LENGTH = 255;
    bytes1 constant ZERO_LENGTH = 0x00;

    error LabelTooLong();
    error NameTooLong();
    error InvalidLabel();
    error InvalidDomain();

    /// @notice Validates a domain name in DNS wire format
    /// @param name The DNS encoded name to validate
    /// @return bool True if the name is valid
    function isValidDomain(bytes memory name) internal pure returns (bool) {
        if (name.length == 0 || name.length > MAX_NAME_LENGTH) return false;

        uint256 position = 0;
        uint256 count = 0;

        while (position < name.length) {
            uint8 labelLength = uint8(name[position]);

            // Check for end of name
            if (labelLength == 0) {
                return position == name.length - 1;
            }

            // Validate label length
            if (labelLength > MAX_LABEL_LENGTH) return false;
            if (position + labelLength + 1 > name.length) return false;

            // Validate label characters
            for (uint256 i = position + 1; i <= position + labelLength; i++) {
                bytes1 ch = name[i];
                if (!_isValidLabelChar(ch)) return false;
            }

            position += labelLength + 1;
            count += 1;

            // Prevent infinite loops
            if (count > 127) return false;
        }

        return false; // Must end with a zero length label
    }

    /// @notice Validates a single DNS label
    /// @param label The unencoded label to validate
    /// @return bool True if the label is valid
    function isValidLabel(bytes memory label) internal pure returns (bool) {
        if (label.length == 0 || label.length > MAX_LABEL_LENGTH) return false;

        for (uint256 i = 0; i < label.length; i++) {
            if (!_isValidLabelChar(label[i])) return false;
        }

        return true;
    }

    /// @notice Concatenates a label with an existing name
    /// @param label The new label to prepend
    /// @param name The existing encoded name
    /// @return bytes The concatenated name in DNS wire format
    function concatenateName(
        bytes memory label,
        bytes memory name
    ) internal pure returns (bytes memory) {
        if (!isValidLabel(label)) revert InvalidLabel();
        if (!isValidDomain(name)) revert InvalidDomain();

        uint256 newLength = label.length + name.length + 1;
        if (newLength > MAX_NAME_LENGTH) revert NameTooLong();

        return abi.encodePacked(uint8(label.length), label, name);
    }

    /// @notice Encodes a domain name from an array of labels
    /// @param labels Array of labels in reverse order (TLD first)
    /// @return bytes The encoded domain name in DNS wire format
    function encodeName(
        string[] memory labels
    ) internal pure returns (bytes memory) {
        bytes memory result = abi.encodePacked(ZERO_LENGTH);

        for (uint256 i = 0; i < labels.length; i++) {
            bytes memory label = bytes(labels[i]);
            if (!isValidLabel(label)) revert InvalidLabel();

            result = concatenateName(label, result);
        }

        return result;
    }

    /// @notice Decodes a DNS wire format name into its labels
    /// @param name The encoded domain name
    /// @return labels Array of decoded labels
    function decodeName(
        bytes memory name
    ) internal pure returns (string[] memory labels) {
        if (!isValidDomain(name)) revert InvalidDomain();

        // Count labels first
        uint256 labelCount = 0;
        uint256 position = 0;

        while (position < name.length) {
            uint8 labelLength = uint8(name[position]);
            if (labelLength == 0) break;
            labelCount++;
            position += labelLength + 1;
        }

        // Decode labels
        labels = new string[](labelCount);
        position = 0;

        for (uint256 i = 0; i < labelCount; i++) {
            uint8 labelLength = uint8(name[position]);
            bytes memory label = new bytes(labelLength);

            for (uint256 j = 0; j < labelLength; j++) {
                label[j] = name[position + 1 + j];
            }

            labels[i] = string(label);
            position += labelLength + 1;
        }

        return labels;
    }

    /// @notice Validates a character for use in a DNS label
    /// @param ch The character to validate
    /// @return bool True if the character is valid
    function _isValidLabelChar(bytes1 ch) private pure returns (bool) {
        // Letters, digits, and hyphens only
        // ASCII: 0-9, A-Z, a-z, -
        return ((ch >= 0x30 && ch <= 0x39) || // 0-9
            (ch >= 0x41 && ch <= 0x5A) || // A-Z
            (ch >= 0x61 && ch <= 0x7A) || // a-z
            ch == 0x2D); // hyphen
    }
}