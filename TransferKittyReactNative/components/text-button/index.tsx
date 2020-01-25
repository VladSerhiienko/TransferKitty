import React from 'react';
import { StyleSheet, Text, TouchableOpacity } from 'react-native';

export default function TextButton(props) {
    const { children } = props;
    return (
        <TouchableOpacity>
            <Text style={{ ...styles.text, ...props.style,}}>{children}</Text>
        </TouchableOpacity>
    );
}

const styles = StyleSheet.create({
    text: {
        color: 'blue',
    },
});
