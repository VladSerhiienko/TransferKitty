import React from 'react';
import { StyleSheet, FlatList, Text, View } from 'react-native';

import Card from '../card';

const DATA = [
    {
        id: 'bd7acbea-c1b1-46c2-aed5-3ad53abb28ba',
        title: 'First Item',
    },
    {
        id: '3ac68afc-c605-48d3-a4f8-fbd91aa97f63',
        title: 'Second Item',
    },
    {
        id: '58694a0f-3da1-471f-bd96-145571e29d72',
        title: 'Third Item',
    },
];

function Item({ title }) {
    return (
        <View style={styles.item}>
            <Text style={styles.title}>{title}</Text>
        </View>
    );
}

export default function History() {
    return (
        <View style={styles.container}>
            <Text style={styles.header}>History</Text>
            <Card>
                <FlatList
                    data={DATA}
                    renderItem={({item}) => <Item title={item.title} />}
                    keyExtractor={item => item.id}
                />
            </Card>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        padding: 20,
        paddingVertical: 25,
        paddingTop: 35,
    },
    header: {
        fontWeight: '500',
    },
    item: {
        // padding: 5,
        marginBottom: 10,
    },
});
