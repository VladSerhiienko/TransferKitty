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
            <View style={styles.rightContainer}>
                <TextButton style={styles.submitButton}>Next</TextButton>
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    navBar: {
        height: 60,
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        backgroundColor: '#fff',
        // borderTopStartRadius: 20,
        // borderTopEndRadius: 20,
        // borderBottomWidth: 1,
        // borderBottomColor: '#cbcbcb',
    },
    leftContainer: {
        flex: 1,
        justifyContent: 'flex-start',
        // paddingLeft: 10,
    },
    rightContainer: {
        flex: 1,
        alignItems: 'flex-end',
    },
    cancelText: {
        paddingLeft: 25,
        color: "#338fe0",
    },
    submitButton: {
        paddingRight: 25,
        color: "#1271c4",
    },
    title: {
        color: '#000',
        fontWeight: '600',
        fontSize: 16,
    },
});
