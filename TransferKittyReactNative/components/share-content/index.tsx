import React, { useRef, useEffect, useState } from 'react';
import { Animated, StyleSheet, Text, View, FlatList, Image, TouchableOpacity, findNodeHandle } from 'react-native';
import { BlurView, VibrancyView } from "@react-native-community/blur";

export interface ImageType {
    file: string;
    text: string;
    orientation: 'w' | 'h';
}

const IMAGES: ImageType[] = [
    {
        file: require('../../assets/images/share/images.jpeg'),
        text: 'images.jpeg',
        orientation: 'h',
    },
    {
        file: require('../../assets/images/share/photo-1531804055935-76f44d7c3621.jpeg'),
        text: 'photo-1531804055935-76f44d7c3621.jpeg',
        orientation: 'h',
    },
    {
        file: require('../../assets/images/share/MADANG-PHOTOS-PAPUA-NEW-GUINEA-0272-1080x635.jpg.optimal.jpg'),
        text: 'MADANG-PHOTOS-PAPUA-NEW-GUINEA-0272-1080x635.jpg.optimal.jpg',
        orientation: 'h',
    },
    {
        file: require('../../assets/images/share/IMG_123_12342.jpg'),
        text: 'IMG_123_12342.jpg',
        orientation: 'h',
    },
    {
        file: require('../../assets/images/share/best-action-photos-2016-red-bull-illume-48-57f6150f74455__880.jpg'),
        text: 'best-action-photos-2016-red-bull-illume-48-57f6150f74455__880.jpg',
        orientation: 'h',
    }
];

export const Item = ({ source, text }) => {
    return (
        <TouchableOpacity style={styles.imageContainer}>
            <Image style={styles.image} source={source} />
            <Text style={styles.imageName} ellipsizeMode='tail' numberOfLines={1}>{text}</Text>
        </TouchableOpacity>
    )
};

export const ShareContent = () => {
    const viewRef = useRef<number|null>(null);
    const [fadeAnim] = useState<number>(new Animated.Value(0));
    const listRef = useRef();

    useEffect(() => {
        Animated.timing(
            fadeAnim,
            {
              toValue: 10,
              duration: 1000,
            }
          ).start();
    }, []);

    return (
        <Animated.View style={styles.container}>
            <BlurView
                style={styles.backdrop}
                blurType="light"
                blurAmount={10}
            />
            <FlatList
                ref={listRef}
                data={IMAGES}
                renderItem={({ item }) => <Item source={item.file} text={item.text} />}
                keyExtractor={item => item.file}
            />
        </Animated.View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    backdrop: {
        position: 'absolute',
        left: 0,
        right: 0,
        top: 0,
        bottom: 0,
        zIndex: 10,
    },
    image: {
        // flex: 1,
        margin: 10,
        width: 90,
        height: 90,
    },
    imageName: {
        maxWidth: '100%',
    },
    imageContainer: {
        flexDirection: 'row',
        alignItems: 'center',
    }
})

export default ShareContent;
