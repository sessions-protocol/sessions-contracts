//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import {Date} from "./interface/ISessions.sol";

library DateTime {
    function isLeapYear(uint16 year) internal pure returns (bool) {
        if (year % 4 != 0) {
            return false;
        }
        if (year % 100 != 0) {
            return true;
        }
        if (year % 400 != 0) {
            return false;
        }
        return true;
    }

    function getWeekday(uint256 timestamp) external pure returns (uint8) {
        return uint8((timestamp / 86400 + 4) % 7);
    }

    function toTimestamp(Date calldata date)
        external
        pure
        returns (uint32 timestamp)
    {
        uint16 year = date.year;
        uint8 month = date.month;
        uint16 day = date.day;

        uint16 i;

        // Year
        for (i = 1970; i < year; i++) {
            if (isLeapYear(i)) {
                timestamp += 31622400;
            } else {
                timestamp += 31536000;
            }
        }

        // Month
        uint8[12] memory monthDayCounts;
        monthDayCounts[0] = 31;
        if (isLeapYear(year)) {
            monthDayCounts[1] = 29;
        } else {
            monthDayCounts[1] = 28;
        }
        monthDayCounts[2] = 31;
        monthDayCounts[3] = 30;
        monthDayCounts[4] = 31;
        monthDayCounts[5] = 30;
        monthDayCounts[6] = 31;
        monthDayCounts[7] = 31;
        monthDayCounts[8] = 30;
        monthDayCounts[9] = 31;
        monthDayCounts[10] = 30;
        monthDayCounts[11] = 31;

        for (i = 1; i < month; i++) {
            timestamp += 86400 * monthDayCounts[i - 1];
        }

        // Day
        timestamp += 86400 * (day - 1);
        return timestamp;
    }
}
