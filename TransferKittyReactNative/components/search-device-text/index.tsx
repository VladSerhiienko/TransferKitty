import React, { useState, useEffect } from 'react';
import { Text } from 'react-native';

const SEARCH_TEMPLATE = 'Looking for someone around';

export const SearchDeviceText = ({ style, deviceCount, delay = 600 }) => {
    const [dotCount, setDotCount] = useState<number>(0);

    useEffect(() => {
        if (!deviceCount) {
            const intervalId = setInterval(() => {
                setDotCount(dotCount => (dotCount + 1) % 4);
            }, delay);
            return () => clearInterval(intervalId);
        }
    }, [deviceCount, delay]);

    const result = deviceCount ? `Found ${deviceCount} devices` : `${SEARCH_TEMPLATE}` + '.'.repeat(dotCount);
    return <Text style={style}>{result}</Text>
}

export default SearchDeviceText;
