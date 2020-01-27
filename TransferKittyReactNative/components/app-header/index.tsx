import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

import textStyles from '../../styles/text';

import TextButton from '../text-button';

export default function AppHeader({ name, style, openSettings = () => { } }) {
    return (
        <View style={{ ...styles.navBar, ...style }}>
            <Text style={textStyles.header}>{name}</Text>
            <TextButton onClick={openSettings} style={styles.settings}>Settings</TextButton>
        </View>
    );
};

const styles = StyleSheet.create({
    navBar: {
        display: 'flex',
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'flex-end',

        // width: '100%',
        borderBottomColor: '#cccccc',
        borderBottomWidth: 1,
        marginHorizontal: 10,

        padding: 20,
        paddingVertical: 25,
        paddingTop: 35,
    },
    settings: {
        color: 'dodgerblue',
        fontWeight: '400',
    },
});
