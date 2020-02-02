import React, {useState} from 'react';
import { StyleSheet, FlatList, Text, View } from 'react-native';

import {Device} from '../../types/device';
import DeviceIcon from '../device-icon';

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

function Item({ name, device }) {
    return (
        <View style={itemStyles.item}>
            <DeviceIcon device={device} />
            <Text style={itemStyles.name}>{name}</Text>
        </View>
    );
}

const itemStyles = StyleSheet.create({
    item: {
        display: 'flex',
        flexDirection: 'row',
        justifyContent: 'flex-start',
        alignItems: 'center',
        marginBottom: 10,
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

export default function DeviceList() {
    const [selected, setSelected] = useState(null);
    return (
        <View style={styles.container}>
            <FlatList
                data={DATA}
                renderItem={({item}) => <Item name={item.name} device={item.device} />}
                keyExtractor={item => item.id}
            />
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        padding: 20,
        paddingVertical: 25,
        paddingTop: 35,
        backgroundColor: 'hsl(0, 0%, 97%)'
    },
});
