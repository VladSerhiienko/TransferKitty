import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

import TextButton from '../text-button';

export default function ShareHeader() {
    return (
        <View style={styles.navBar}>
            <View style={styles.leftContainer}>
                <TextButton style={styles.cancelText}>Cancel</TextButton>
            </View>
            <Text style={styles.title}>Catena</Text>
            <View style={{flex: 1}} />
        </View>
    );
}

const styles = StyleSheet.create({
    navBar: {
        height: 60,
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        backgroundColor: '#f1f1f1',
        borderTopStartRadius: 20,
        borderTopEndRadius: 20,
        borderBottomWidth: 1,
        borderBottomColor: '#cbcbcb',
    },
    leftContainer: {
        flex: 1,
        flexDirection: 'row',
        justifyContent: 'flex-start',
        // paddingLeft: 10,
    },
    cancelText: {
        paddingLeft: 15,
        color: "#338fe0",
    },
    title: {
        color: '#000',
        fontWeight: '600',
        fontSize: 16,
    },
});
