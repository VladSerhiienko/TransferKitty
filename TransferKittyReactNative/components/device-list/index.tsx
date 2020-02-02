import React, { useState, useEffect, useRef, useLayoutEffect } from 'react';
import { Animated, Modal, StyleSheet, TouchableOpacity, Text, View } from 'react-native';

import { Device } from '../../types/device';
import DeviceIcon from '../device-icon';
import SearchDeviceText from '../search-device-text';

interface BTIdentificator {
    id: string;
    name: string;
    device: Device;
}

const DATA = [
    {
        id: '58694a0f-3da1-471f-bd96-145571e29d72',
        name: `Vasyl's iPhone`,
        device: Device.iPhone,
    },
    {
        id: 'bd7acbea-c1b1-46c2-aed5-3ad53abb28ba',
        name: `Vladyslav's iPhone`,
        device: Device.iPhone,
    },
    {
        id: '3ac68afc-c605-48d3-a4f8-fbd91aa97f63',
        name: `Vladyslav's MacBook`,
        device: Device.macbook,
    },
];

function Item({ id, name, device, style, onSelect }) {
    return (
        <TouchableOpacity style={{ ...itemStyles.item, ...style }} onPress={() => onSelect(id)}>
            <DeviceIcon device={device} />
            <Text style={itemStyles.name}>{name}</Text>
        </TouchableOpacity>
    );
}

const itemStyles = StyleSheet.create({
    item: {
        display: 'flex',
        flexDirection: 'row',
        justifyContent: 'flex-start',
        alignItems: 'center',
        marginBottom: 15,
    },
    name: {
        fontWeight: '400',
        fontSize: 16,
        marginLeft: 20,
    },
    icon: {
        fontSize: 28,
    }
})

export default function DeviceList({ onSelect, selected }) {
    const [devices, setDevices] = useState<BTIdentificator[]>([DATA[0]]);
    const [found, setFound] = useState(false);


    useEffect(() => {
        if (devices.length < 3) {
            const t1 = setTimeout(() => {
                setDevices(devices => [...devices, DATA[1]]);
            }, 1000);
            const t2 = setTimeout(() => {
                setDevices(devices => [...devices, DATA[2]]);
                setFound(true);
            }, 2500);
            return () => {
                clearTimeout(t1);
                clearTimeout(t2);
            }
        }
    }, []);

    const isLast = index => index === (devices.length - 1);

    return (
        <View style={styles.container}>
            <SearchDeviceText style={{ marginTop: 20, fontSize: 14, fontWeight: '500' }} deviceCount={found && devices.length} />
            <View style={styles.deviceList}>
                {devices.map((device, index) => <Item key={device.id} onSelect={onSelect} id={device.id} name={device.name} device={device.device} style={isLast(index) ? { marginBottom: 0 } : {}} />)}
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    label: {
        // alignSelf: 'center',
        // marginTop: -10,
        fontSize: 14,
        fontWeight: '600',
        marginTop: -10,
        marginLeft: 10,
        // backgroundColor: '#fff',
        width: 'auto',
    },
    deviceList: {
        padding: 10,
        paddingLeft: 20,
        paddingVertical: 20,
    },
    container: {
        // flex: 1,
        paddingTop: 0,
        marginTop: 0,
        padding: 20,
        paddingBottom: 0,
        paddingVertical: 25,
        // backgroundColor: '#f7f7f7',
    },
    list: {
        paddingTop: 10,
        paddingHorizontal: 10,
    }
});
